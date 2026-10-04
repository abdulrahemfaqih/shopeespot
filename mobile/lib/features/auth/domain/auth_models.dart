class AuthUser {
  final String id;
  final String email;

  const AuthUser({required this.id, required this.email});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'email': email};
}

class AuthTokenPair {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AuthUser user;

  const AuthTokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthTokenPair.fromJson(Map<String, dynamic> json) {
    return AuthTokenPair(
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 900,
      user: json['user'] is Map<String, dynamic>
          ? AuthUser.fromJson(json['user'] as Map<String, dynamic>)
          : const AuthUser(id: '', email: ''),
    );
  }
}

class AuthException implements Exception {
  final String code;
  final String message;

  const AuthException({required this.code, required this.message});

  @override
  String toString() => 'AuthException($code): $message';
}
