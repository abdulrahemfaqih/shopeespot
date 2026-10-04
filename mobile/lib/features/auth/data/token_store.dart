import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class ITokenStore {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<String?> getUserId();
  Future<String?> getUserEmail();
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? userId,
    String? userEmail,
  });
  Future<void> saveAccessToken(String accessToken);
  Future<void> saveRefreshToken(String refreshToken);
  Future<void> clear();
  Future<bool> hasValidSession();
}

class TokenStore implements ITokenStore {
  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUserId = 'auth_user_id';
  static const String _keyUserEmail = 'auth_user_email';

  final FlutterSecureStorage _storage;

  TokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> getAccessToken() => _storage.read(key: _keyAccessToken);

  @override
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefreshToken);

  @override
  Future<String?> getUserId() => _storage.read(key: _keyUserId);

  @override
  Future<String?> getUserEmail() => _storage.read(key: _keyUserEmail);

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? userId,
    String? userEmail,
  }) async {
    // Write refresh token first
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
    await _storage.write(key: _keyAccessToken, value: accessToken);
    if (userId != null) {
      await _storage.write(key: _keyUserId, value: userId);
    }
    if (userEmail != null) {
      await _storage.write(key: _keyUserEmail, value: userEmail);
    }
  }

  @override
  Future<void> saveAccessToken(String accessToken) =>
      _storage.write(key: _keyAccessToken, value: accessToken);

  @override
  Future<void> saveRefreshToken(String refreshToken) =>
      _storage.write(key: _keyRefreshToken, value: refreshToken);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUserEmail);
  }

  @override
  Future<bool> hasValidSession() async {
    final refresh = await getRefreshToken();
    return refresh != null && refresh.isNotEmpty;
  }
}

final tokenStoreProvider = Provider<ITokenStore>((ref) {
  return TokenStore();
});
