import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env.dart';
import '../../features/auth/data/auth_interceptor.dart';
import '../../features/auth/data/token_store.dart';

class ApiClient {
  final Dio clientDio;
  final Dio refreshDio;

  ApiClient._({required this.clientDio, required this.refreshDio});

  factory ApiClient.create({
    required ITokenStore tokenStore,
    String? baseUrl,
    void Function()? onSessionExpired,
  }) {
    final base = baseUrl ?? Env.apiBaseUrl;

    final refreshDio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    final clientDio = Dio(
      BaseOptions(
        baseUrl: base,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    final interceptor = AuthInterceptor(
      tokenStore: tokenStore,
      refreshDio: refreshDio,
      clientDio: clientDio,
      onSessionExpired: onSessionExpired,
    );

    clientDio.interceptors.add(interceptor);

    return ApiClient._(clientDio: clientDio, refreshDio: refreshDio);
  }
}

final sessionExpiredEventProvider = StateProvider<bool>((ref) => false);

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStore = ref.watch(tokenStoreProvider);
  return ApiClient.create(
    tokenStore: tokenStore,
    onSessionExpired: () {
      ref.read(sessionExpiredEventProvider.notifier).state = true;
    },
  );
});

final dioProvider = Provider<Dio>((ref) {
  return ref.watch(apiClientProvider).clientDio;
});
