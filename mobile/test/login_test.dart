import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopeespot/app/app.dart';
import 'package:shopeespot/core/location/location_provider.dart';
import 'package:shopeespot/core/location/location_service.dart';
import 'package:shopeespot/features/auth/data/auth_api.dart';
import 'package:shopeespot/features/auth/data/token_store.dart';
import 'package:shopeespot/features/auth/domain/auth_models.dart';
import 'package:shopeespot/features/auth/domain/session_state.dart';
import 'package:shopeespot/features/auth/presentation/auth_controller.dart';
import 'package:shopeespot/features/auth/presentation/login_screen.dart';
import 'package:shopeespot/features/map/presentation/map_controller.dart';
import 'package:shopeespot/features/map/presentation/map_screen.dart';

import 'auth_test.dart';

class MockAuthApi implements IAuthApi {
  AuthTokenPair? loginResult;
  AuthTokenPair? registerResult;
  AuthException? errorToThrow;

  String? lastLoginEmail;
  String? lastLoginPassword;
  String? lastRegisterEmail;
  String? lastRegisterPassword;

  @override
  Future<AuthTokenPair> login({
    required String email,
    required String password,
  }) async {
    lastLoginEmail = email;
    lastLoginPassword = password;
    if (errorToThrow != null) throw errorToThrow!;
    return loginResult ??
        const AuthTokenPair(
          accessToken: 'at-token',
          refreshToken: 'rt-token',
          expiresIn: 900,
          user: AuthUser(id: 'u1', email: 'driver@test.com'),
        );
  }

  @override
  Future<AuthTokenPair> register({
    required String email,
    required String password,
  }) async {
    lastRegisterEmail = email;
    lastRegisterPassword = password;
    if (errorToThrow != null) throw errorToThrow!;
    return registerResult ??
        const AuthTokenPair(
          accessToken: 'at-token',
          refreshToken: 'rt-token',
          expiresIn: 900,
          user: AuthUser(id: 'u1', email: 'driver@test.com'),
        );
  }

  @override
  Future<AuthTokenPair> refresh({required String refreshToken}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> logout({required String refreshToken}) async {}
}

class _StaticLocationNotifier extends UserLocationNotifier {
  _StaticLocationNotifier(this._state);
  final LocationState _state;

  @override
  LocationState build() => _state;
}

class _StaticCameraNotifier extends MapCameraNotifier {
  @override
  Future<MapCameraState> build() async {
    return const MapCameraState(
      center: LatLng(defaultLat, defaultLng),
      zoom: defaultZoom,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LoginScreen widget and interaction tests', () {
    testWidgets(
      'renders login form and switches between Masuk and Daftar mode',
      (tester) async {
        final tokenStore = FakeTokenStore();
        final mockAuthApi = MockAuthApi();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStoreProvider.overrideWithValue(tokenStore),
              authApiProvider.overrideWithValue(mockAuthApi),
            ],
            child: const MaterialApp(home: LoginScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Initial login mode
        expect(find.text('Masuk SpotShopee'), findsOneWidget);
        expect(find.text('Masuk'), findsOneWidget);
        expect(find.text('Belum punya akun? Daftar'), findsOneWidget);

        // Tap toggle to register mode
        await tester.tap(find.text('Belum punya akun? Daftar'));
        await tester.pumpAndSettle();

        expect(find.text('Daftar Akun'), findsOneWidget);
        expect(find.text('Daftar'), findsOneWidget);
        expect(find.text('Sudah punya akun? Masuk'), findsOneWidget);
      },
    );

    testWidgets('successful login updates tokens and session state', (
      tester,
    ) async {
      final tokenStore = FakeTokenStore();
      final mockAuthApi = MockAuthApi();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStoreProvider.overrideWithValue(tokenStore),
            authApiProvider.overrideWithValue(mockAuthApi),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Fill in valid email and password
      await tester.enterText(
        find.byType(TextFormField).first,
        'driver@shopee.com',
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'secretPassword123',
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(mockAuthApi.lastLoginEmail, 'driver@shopee.com');
      expect(mockAuthApi.lastLoginPassword, 'secretPassword123');
      expect(await tokenStore.getAccessToken(), 'at-token');
      expect(await tokenStore.getRefreshToken(), 'rt-token');
    });

    testWidgets('shows error banner when server returns error', (tester) async {
      final tokenStore = FakeTokenStore();
      final mockAuthApi = MockAuthApi()
        ..errorToThrow = const AuthException(
          code: 'invalid_credentials',
          message: 'Email atau kata sandi salah.',
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStoreProvider.overrideWithValue(tokenStore),
            authApiProvider.overrideWithValue(mockAuthApi),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'wrong@test.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'wrongpassword');
      await tester.tap(find.text('Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Email atau kata sandi salah.'), findsOneWidget);
    });
  });

  group('Router redirect and offline session tests (T-28)', () {
    testWidgets('unauthenticated user is redirected to /login', (tester) async {
      final tokenStore = FakeTokenStore(); // empty session

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStoreProvider.overrideWithValue(tokenStore),
            sessionStateProvider.overrideWith(
              (ref) => SessionNotifier(
                tokenStore,
                MockAuthApi(),
                initialState: const SessionState.unauthenticated(),
              ),
            ),
          ],
          child: const SpotShopeeApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Should be redirected to LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(MapScreen), findsNothing);
    });

    testWidgets(
      'offline launch with saved session opens directly to MapScreen (T-28 completion criteria)',
      (tester) async {
        // Simulate stored tokens from previous login
        final tokenStore = FakeTokenStore()
          ..accessToken = 'stored-access-token'
          ..refreshToken = 'stored-refresh-token'
          ..userId = 'user-saved-id'
          ..userEmail = 'driver@saved.com';

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              tokenStoreProvider.overrideWithValue(tokenStore),
              userLocationProvider.overrideWith(
                () => _StaticLocationNotifier(const LocationWaiting()),
              ),
              mapCameraProvider.overrideWith(() => _StaticCameraNotifier()),
              sessionStateProvider.overrideWith(
                (ref) => SessionNotifier(
                  tokenStore,
                  MockAuthApi(),
                  initialState: const SessionState.authenticated(
                    userId: 'user-saved-id',
                    userEmail: 'driver@saved.com',
                  ),
                ),
              ),
            ],
            child: const SpotShopeeApp(),
          ),
        );
        await tester.pumpAndSettle();

        // MUST immediately render MapScreen without requiring any network call or server connection
        expect(find.byType(MapScreen), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      },
    );
  });
}
