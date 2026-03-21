class AuthTokens {
  const AuthTokens({
    required this.tokenType,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String tokenType;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      tokenType: json['token_type'] as String? ?? 'Bearer',
      accessToken: json['access_token'] as String? ?? '',
      refreshToken: json['refresh_token'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 0,
    );
  }

  factory AuthTokens.mock() {
    return const AuthTokens(
      tokenType: 'Bearer',
      accessToken: 'mock_access_token',
      refreshToken: 'mock_refresh_token',
      expiresIn: 900,
    );
  }
}
