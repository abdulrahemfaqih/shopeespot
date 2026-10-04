import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_api.dart';
import '../data/token_store.dart';
import '../domain/auth_models.dart';
import '../domain/session_state.dart';

class SessionNotifier extends StateNotifier<SessionState> {
  final ITokenStore _tokenStore;
  final IAuthApi _authApi;

  SessionNotifier(this._tokenStore, this._authApi, {SessionState? initialState})
    : super(initialState ?? const SessionState.initial()) {
    if (initialState == null) {
      _init();
    }
  }

  Future<void> _init() async {
    final hasSession = await _tokenStore.hasValidSession();
    if (hasSession) {
      final userId = await _tokenStore.getUserId();
      final userEmail = await _tokenStore.getUserEmail();
      state = SessionState.authenticated(
        userId: userId ?? '',
        userEmail: userEmail ?? '',
      );
    } else {
      state = const SessionState.unauthenticated();
    }
  }

  void setAuthenticated({required String userId, required String userEmail}) {
    state = SessionState.authenticated(userId: userId, userEmail: userEmail);
  }

  void setExpired() {
    state = SessionState.expired(
      userId: state.userId,
      userEmail: state.userEmail,
    );
  }

  Future<void> logout() async {
    final refresh = await _tokenStore.getRefreshToken();
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _authApi.logout(refreshToken: refresh);
      } catch (_) {
        // Ignore network failure on logout
      }
    }
    await _tokenStore.clear();
    state = const SessionState.unauthenticated();
  }
}

final sessionStateProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
      final tokenStore = ref.watch(tokenStoreProvider);
      final authApi = ref.watch(authApiProvider);
      return SessionNotifier(tokenStore, authApi);
    });

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final bool isRegisterMode;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.isRegisterMode = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? isRegisterMode,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isRegisterMode: isRegisterMode ?? this.isRegisterMode,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final IAuthApi _authApi;
  final ITokenStore _tokenStore;
  final SessionNotifier _sessionNotifier;

  AuthController({
    required IAuthApi authApi,
    required ITokenStore tokenStore,
    required SessionNotifier sessionNotifier,
  }) : _authApi = authApi,
       _tokenStore = tokenStore,
       _sessionNotifier = sessionNotifier,
       super(const AuthState());

  void toggleMode() {
    state = state.copyWith(
      isRegisterMode: !state.isRegisterMode,
      clearError: true,
    );
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<bool> submit({required String email, required String password}) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      state = state.copyWith(errorMessage: 'Format email tidak valid.');
      return false;
    }

    if (password.length < 8) {
      state = state.copyWith(
        errorMessage: 'Kata sandi minimal harus 8 karakter.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final AuthTokenPair pair;
      if (state.isRegisterMode) {
        pair = await _authApi.register(email: trimmedEmail, password: password);
      } else {
        pair = await _authApi.login(email: trimmedEmail, password: password);
      }

      await _tokenStore.saveTokens(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
        userId: pair.user.id,
        userEmail: pair.user.email,
      );

      _sessionNotifier.setAuthenticated(
        userId: pair.user.id,
        userEmail: pair.user.email,
      );

      state = state.copyWith(isLoading: false);
      return true;
    } on AuthException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal terhubung ke server. Periksa koneksi internet.',
      );
      return false;
    }
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final authApi = ref.watch(authApiProvider);
    final tokenStore = ref.watch(tokenStoreProvider);
    final sessionNotifier = ref.watch(sessionStateProvider.notifier);
    return AuthController(
      authApi: authApi,
      tokenStore: tokenStore,
      sessionNotifier: sessionNotifier,
    );
  },
);
