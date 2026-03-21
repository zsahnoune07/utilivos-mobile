class AccessTokenStore {
  String? _token;

  String? get token => _token;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  void write(String token) {
    _token = token;
  }

  void clear() {
    _token = null;
  }
}
