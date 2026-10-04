import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/auth_models.dart';

abstract class IAuthApi {
  Future<AuthTokenPair> register({
    required String email,
    required String password,
  });

  Future<AuthTokenPair> login({
    required String email,
    required String password,
  });

  Future<AuthTokenPair> refresh({required String refreshToken});

  Future<void> logout({required String refreshToken});
}

class AuthApi implements IAuthApi {
  final Dio _dio;

  AuthApi(this._dio);

  @override
  Future<AuthTokenPair> register({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/register',
        data: {'email': email, 'password': password},
      );
      return AuthTokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  @override
  Future<AuthTokenPair> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthTokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  @override
  Future<AuthTokenPair> refresh({required String refreshToken}) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      return AuthTokenPair.fromJson(res.data!);
    } on DioException catch (e) {
      throw _parseError(e);
    }
  }

  @override
  Future<void> logout({required String refreshToken}) async {
    try {
      await _dio.post<void>(
        '/v1/auth/logout',
        data: {'refresh_token': refreshToken},
      );
    } on DioException catch (e) {
      // Logout is idempotent, ignore network or 401 errors
      if (e.response?.statusCode != 204 && e.response?.statusCode != 200) {
        throw _parseError(e);
      }
    }
  }

  AuthException _parseError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        return AuthException(
          code: error['code'] as String? ?? 'unknown',
          message: error['message'] as String? ?? 'Terjadi kesalahan.',
        );
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const AuthException(
        code: 'network_timeout',
        message: 'Koneksi ke server terputus atau batas waktu habis.',
      );
    }

    return const AuthException(
      code: 'network_error',
      message: 'Gagal terhubung ke server.',
    );
  }
}

final authApiProvider = Provider<IAuthApi>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthApi(apiClient.refreshDio);
});
