import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'token_store.dart';

class AuthInterceptor extends Interceptor {
  final ITokenStore tokenStore;
  final Dio refreshDio;
  final Dio clientDio;
  final VoidCallback? onSessionExpired;

  Completer<String?>? _refreshCompleter;

  AuthInterceptor({
    required this.tokenStore,
    required this.refreshDio,
    required this.clientDio,
    this.onSessionExpired,
  });

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Only attach Bearer if not already explicitly provided
    if (!options.headers.containsKey('Authorization')) {
      final token = await tokenStore.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final isAuthEndpoint = err.requestOptions.path.contains('/v1/auth/');

    // Do not trigger refresh if request was not 401 or if it was already an auth call
    if (!isUnauthorized || isAuthEndpoint) {
      return handler.next(err);
    }

    // Trigger or join single-flight refresh
    final newToken = await _singleFlightRefresh();
    if (newToken == null) {
      return handler.next(err);
    }

    // Retry request with fresh access token
    try {
      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newToken';
      final response = await clientDio.fetch(retryOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<String?> _singleFlightRefresh() {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    _executeRefresh()
        .then((token) {
          if (!completer.isCompleted) completer.complete(token);
        })
        .catchError((dynamic _) {
          if (!completer.isCompleted) completer.complete(null);
        })
        .whenComplete(() {
          _refreshCompleter = null;
        });

    return completer.future;
  }

  Future<String?> _executeRefresh() async {
    final currentRefresh = await tokenStore.getRefreshToken();
    if (currentRefresh == null || currentRefresh.isEmpty) {
      onSessionExpired?.call();
      return null;
    }

    try {
      final response = await refreshDio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': currentRefresh},
      );

      final data = response.data;
      if (data == null) {
        return null;
      }

      final newAccessToken = data['access_token'] as String?;
      final newRefreshToken = data['refresh_token'] as String?;

      if (newAccessToken != null && newRefreshToken != null) {
        // Write new refresh token to secure storage BEFORE access token
        await tokenStore.saveRefreshToken(newRefreshToken);
        await tokenStore.saveAccessToken(newAccessToken);
        return newAccessToken;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // invalid_refresh or reuse_detected: session expired
        onSessionExpired?.call();
      }
    } catch (_) {
      // Network or serialization error
    }

    return null;
  }
}
