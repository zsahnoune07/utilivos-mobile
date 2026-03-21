import 'package:flutter/foundation.dart';

import 'models/auth_tokens.dart';
import 'models/auth_user.dart';
import 'session_manager.dart';

enum SessionState { initializing, authenticated, unauthenticated }

class SessionController extends ChangeNotifier {
  SessionController({required SessionManager sessionManager})
    : _sessionManager = sessionManager;

  final SessionManager _sessionManager;

  SessionState _state = SessionState.initializing;
  bool _bootstrapStarted = false;

  SessionState get state => _state;
  bool get isInitializing => _state == SessionState.initializing;
  bool get isAuthenticated => _state == SessionState.authenticated;
  bool get hasAccessToken => _sessionManager.hasAccessToken;

  Future<void> bootstrap() async {
    if (_bootstrapStarted) {
      return;
    }
    _bootstrapStarted = true;

    _state = SessionState.initializing;
    notifyListeners();

    // Keep splash visible while app bootstrap runs.
    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Session restore (refresh-token bootstrapping) lands in Phase 3.2.
    _state = _sessionManager.hasAccessToken
        ? SessionState.authenticated
        : SessionState.unauthenticated;
    notifyListeners();
  }

  Future<void> signInWithMockSession() async {
    await _sessionManager.saveTokens(AuthTokens.mock());
    _state = SessionState.authenticated;
    notifyListeners();
  }

  Future<void> login({required String email, required String password}) async {
    await _sessionManager.login(email: email, password: password);
    _state = SessionState.authenticated;
    notifyListeners();
  }

  Future<void> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    await _sessionManager.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    _state = SessionState.authenticated;
    notifyListeners();
  }

  Future<AuthUser> fetchCurrentUser() {
    return _sessionManager.me();
  }

  Future<void> signOut() async {
    try {
      await _sessionManager.logout();
    } catch (_) {
      // Network logout failure should still end the local session.
    }
    _state = SessionState.unauthenticated;
    notifyListeners();
  }

  Future<void> clearLocalSession() async {
    await _sessionManager.clearTokens();
    _state = SessionState.unauthenticated;
    notifyListeners();
  }
}
