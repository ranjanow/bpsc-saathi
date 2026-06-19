import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// AuthProvider — manages authentication state across the app.
///
/// Wraps [AuthService] with [ChangeNotifier] for reactive UI updates.
/// Used by [AppShell] to gate access to protected screens.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _error;
  Map<String, dynamic>? _user;

  /// Whether the auth state is still being determined.
  bool get isLoading => _isLoading;

  /// Whether the user is authenticated.
  bool get isAuthenticated => _isAuthenticated;

  /// The current user data.
  Map<String, dynamic>? get user => _user;

  /// Current error message (null if no error).
  String? get error => _error;

  /// The underlying auth service (for API headers).
  AuthService get authService => _authService;

  /// User's display name.
  String get displayName =>
      _user?['fullName'] as String? ?? _user?['email'] as String? ?? 'User';

  /// User's email.
  String get email => _user?['email'] as String? ?? '';

  /// User's role.
  String get role => _user?['role'] as String? ?? 'student';

  /// Initialize — check if user is already logged in.
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.init();
      _isAuthenticated = _authService.isAuthenticated;
      _user = _authService.userData;
    } catch (_) {
      _isAuthenticated = false;
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Signup with email and password.
  Future<bool> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _authService.signup(
        fullName: fullName,
        email: email,
        password: password,
      );
      _isAuthenticated = true;
      _user = data['user'] as Map<String, dynamic>;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection error. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Login with email and password.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _authService.login(
        email: email,
        password: password,
      );
      _isAuthenticated = true;
      _user = data['user'] as Map<String, dynamic>;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection error. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Google Sign-In.
  Future<bool> googleSignIn({
    required String email,
    required String fullName,
    String? avatarUrl,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _authService.googleSignIn(
        email: email,
        fullName: fullName,
        avatarUrl: avatarUrl,
      );
      _isAuthenticated = true;
      _user = data['user'] as Map<String, dynamic>;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection error. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout.
  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _user = null;
    _error = null;
    notifyListeners();
  }

  /// Forgot password.
  Future<void> forgotPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.forgotPassword(email);
    } catch (_) {
      // Silent — we always show success to prevent enumeration
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Clear any error state.
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
