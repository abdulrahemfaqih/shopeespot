import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopeespot/features/auth/data/auth_api.dart';
import 'package:shopeespot/features/auth/data/auth_interceptor.dart';
import 'package:shopeespot/features/auth/data/token_store.dart';
import 'package:shopeespot/features/auth/domain/auth_models.dart';
import 'package:shopeespot/features/auth/domain/session_state.dart';

class FakeTokenStore implements ITokenStore {
  String? accessToken;
  String? refreshToken;
  String? userId;
  String? userEmail;

  final List<String> operationLog = [];

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<String?> getRefreshToken() async => refreshToken;

  @override
  Future<String?> getUserId() async => userId;

  @override
  Future<String?> getUserEmail() async => userEmail;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? userId,
    String? userEmail,
  }) async {
    operationLog.add('saveRefreshToken');
    this.refreshToken = refreshToken;
    operationLog.add('saveAccessToken');
    this.accessToken = accessToken;
    this.userId = userId;
    this.userEmail = userEmail;
  }

  @override
  Future<void> saveAccessToken(String accessToken) async {
    operationLog.add('saveAccessToken');
    this.accessToken = accessToken;
  }

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    operationLog.add('saveRefreshToken');
    this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
    userId = null;
    userEmail = null;
  }

  @override
  Future<bool> hasValidSession() async =>
      refreshToken != null && refreshToken!.isNotEmpty;
}

class FakeAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(Map<String, dynamic> data, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(data),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

void main() {
  group('TokenStore unit tests', () {
    test('saves and clears tokens correctly', () async {
      final store = FakeTokenStore();

      expect(await store.hasValidSession(), isFalse);

      await store.saveTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        userId: 'user-1',
        userEmail: 'driver@example.com',
      );

      expect(await store.getAccessToken(), 'access-1');
      expect(await store.getRefreshToken(), 'refresh-1');
      expect(await store.getUserId(), 'user-1');
      expect(await store.getUserEmail(), 'driver@example.com');
      expect(await store.hasValidSession(), isTrue);

      await store.clear();
      expect(await store.getAccessToken(), isNull);
      expect(await store.getRefreshToken(), isNull);
      expect(await store.hasValidSession(), isFalse);
    });
  });

  group('SessionState tests', () {
    test('status getters work correctly', () {
      const s1 = SessionState.unauthenticated();
      expect(s1.isAuthenticated, isFalse);
      expect(s1.isExpired, isFalse);

      const s2 = SessionState.authenticated(
        userId: 'u1',
        userEmail: 'driver@test.com',
      );
      expect(s2.isAuthenticated, isTrue);
      expect(s2.isExpired, isFalse);

      const s3 = SessionState.expired(userId: 'u1');
      expect(s3.isAuthenticated, isFalse);
      expect(s3.isExpired, isTrue);
    });
  });

  group('AuthInterceptor single-flight refresh tests', () {
    test('two concurrent 401 requests trigger only one refresh call', () async {
      final tokenStore = FakeTokenStore()
        ..accessToken = 'expired-access-token'
        ..refreshToken = 'valid-refresh-token';

      var refreshCallCount = 0;
      var protectedEndpointCallCount = 0;

      final refreshDio = Dio(BaseOptions(baseUrl: 'http://test'));
      final clientDio = Dio(BaseOptions(baseUrl: 'http://test'));

      refreshDio.httpClientAdapter = FakeAdapter((options) async {
        if (options.path == '/v1/auth/refresh') {
          refreshCallCount++;
          // Simulate slight network delay to guarantee concurrent overlap
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return jsonResponse({
            'access_token': 'new-access-token',
            'refresh_token': 'new-refresh-token',
            'expires_in': 900,
            'user': {'id': 'user-1', 'email': 'test@example.com'},
          }, 200);
        }
        return jsonResponse({}, 404);
      });

      clientDio.httpClientAdapter = FakeAdapter((options) async {
        if (options.path == '/v1/sync') {
          protectedEndpointCallCount++;
          final authHeader = options.headers['Authorization'] as String?;

          // Fail if token is old, succeed if token is refreshed
          if (authHeader == 'Bearer new-access-token') {
            return jsonResponse({'status': 'synced'}, 200);
          }
          return jsonResponse({
            'error': {'code': 'token_expired', 'message': 'Token expired'},
          }, 401);
        }
        return jsonResponse({}, 404);
      });

      var sessionExpiredCalled = false;
      final interceptor = AuthInterceptor(
        tokenStore: tokenStore,
        refreshDio: refreshDio,
        clientDio: clientDio,
        onSessionExpired: () => sessionExpiredCalled = true,
      );
      clientDio.interceptors.add(interceptor);

      // Fire two concurrent requests simultaneously
      final future1 = clientDio.post<Map<String, dynamic>>('/v1/sync');
      final future2 = clientDio.post<Map<String, dynamic>>('/v1/sync');

      final results = await Future.wait([future1, future2]);

      // Both should succeed with 200
      expect(results[0].statusCode, 200);
      expect(results[1].statusCode, 200);
      expect(results[0].data?['status'], 'synced');
      expect(results[1].data?['status'], 'synced');

      // CRITICAL: Exactly 1 refresh call was made!
      expect(refreshCallCount, 1);
      expect(protectedEndpointCallCount, 4);
      expect(sessionExpiredCalled, isFalse);

      // Verify write order: new refresh token is saved BEFORE new access token
      expect(tokenStore.operationLog, contains('saveRefreshToken'));
      final refreshIdx = tokenStore.operationLog.indexOf('saveRefreshToken');
      final accessIdx = tokenStore.operationLog.indexOf('saveAccessToken');
      expect(refreshIdx, lessThan(accessIdx));

      // Token store updated with new tokens
      expect(await tokenStore.getAccessToken(), 'new-access-token');
      expect(await tokenStore.getRefreshToken(), 'new-refresh-token');
    });

    test(
      'refresh failure with 401 triggers onSessionExpired without deleting data',
      () async {
        final tokenStore = FakeTokenStore()
          ..accessToken = 'expired-access-token'
          ..refreshToken = 'revoked-refresh-token';

        final refreshDio = Dio(BaseOptions(baseUrl: 'http://test'));
        final clientDio = Dio(BaseOptions(baseUrl: 'http://test'));

        refreshDio.httpClientAdapter = FakeAdapter((options) async {
          return jsonResponse({
            'error': {'code': 'invalid_refresh', 'message': 'Invalid refresh'},
          }, 401);
        });

        clientDio.httpClientAdapter = FakeAdapter((options) async {
          return jsonResponse({
            'error': {'code': 'token_expired', 'message': 'Token expired'},
          }, 401);
        });

        var sessionExpiredCalled = false;
        final interceptor = AuthInterceptor(
          tokenStore: tokenStore,
          refreshDio: refreshDio,
          clientDio: clientDio,
          onSessionExpired: () => sessionExpiredCalled = true,
        );
        clientDio.interceptors.add(interceptor);

        expect(
          () => clientDio.post<Map<String, dynamic>>('/v1/sync'),
          throwsA(isA<DioException>()),
        );

        // Give async error handling a moment to settle
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(sessionExpiredCalled, isTrue);
        // Data in token store should NOT be deleted automatically
        expect(await tokenStore.getRefreshToken(), 'revoked-refresh-token');
      },
    );
  });

  group('AuthApi tests', () {
    test('login success parses AuthTokenPair', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.httpClientAdapter = FakeAdapter((options) async {
        if (options.path == '/v1/auth/login') {
          return jsonResponse({
            'access_token': 'at-123',
            'refresh_token': 'rt-456',
            'expires_in': 900,
            'user': {'id': 'user-uuid', 'email': 'driver@example.com'},
          }, 200);
        }
        return jsonResponse({}, 404);
      });

      final api = AuthApi(dio);
      final pair = await api.login(
        email: 'driver@example.com',
        password: 'password123',
      );

      expect(pair.accessToken, 'at-123');
      expect(pair.refreshToken, 'rt-456');
      expect(pair.user.email, 'driver@example.com');
      expect(pair.user.id, 'user-uuid');
    });

    test('login error throws AuthException with code', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://test'));
      dio.httpClientAdapter = FakeAdapter((options) async {
        return jsonResponse({
          'error': {
            'code': 'invalid_credentials',
            'message': 'Email atau kata sandi salah.',
          },
        }, 401);
      });

      final api = AuthApi(dio);

      expect(
        () => api.login(email: 'driver@test.com', password: 'wrong'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.code,
            'code',
            'invalid_credentials',
          ),
        ),
      );
    });
  });
}
