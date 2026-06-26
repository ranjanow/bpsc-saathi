import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../env.dart';

/// Authentication service — handles signup, login, token management.
///
/// Stores tokens in SharedPreferences. In production on mobile,
/// consider flutter_secure_storage for encrypted storage.
class AuthService {
  /// Resolves the API base URL:
  /// 1. If API_URL is set via --dart-define, use it (production).
  /// 2. Otherwise, auto-detect localhost for local development.
  static final String _baseUrl = _resolveBaseUrl();

  static String _resolveBaseUrl() {
    if (Environment.apiUrl.isNotEmpty) return Environment.apiUrl;
    // Local development auto-detection
    return 'http://localhost:8080';
  }

  static const String _accessTokenKey = 'bpsc_access_token';
  static const String _refreshTokenKey = 'bpsc_refresh_token';
  static const String _userDataKey = 'bpsc_user_data';

  String? _accessToken;
  String? _refreshToken;
  Map<String, dynamic>? _userData;

  /// Current access token (null if not authenticated).
  String? get accessToken => _accessToken;

  /// Current user data.
  Map<String, dynamic>? get userData => _userData;

  /// Whether the user is authenticated.
  bool get isAuthenticated => _accessToken != null;

  /// Initialize — load tokens from local storage.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_accessTokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
    final userJson = prefs.getString(_userDataKey);
    if (userJson != null) {
      _userData = json.decode(userJson) as Map<String, dynamic>;
    }

    // If we have a refresh token but no access token, try to refresh
    if (_accessToken == null && _refreshToken != null) {
      try {
        await refreshToken();
      } catch (_) {
        await _clearTokens();
      }
    }
  }

  /// Save tokens to local storage.
  Future<void> _saveTokens(String accessToken, String refreshToken, Map<String, dynamic> user) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _userData = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
    await prefs.setString(_userDataKey, json.encode(user));
  }

  /// Clear all stored tokens.
  Future<void> _clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    _userData = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userDataKey);
  }

  /// Standard headers for API requests.
  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
  };

  /// Headers with auth token.
  Map<String, String> get authHeaders => {
    ..._headers,
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  // ─── Signup ────────────────────────────────────────────────────────────────

  /// Register a new user with email and password.
  Future<Map<String, dynamic>> signup({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/signup'),
      headers: _headers,
      body: json.encode({
        'fullName': fullName,
        'email': email,
        'password': password,
      }),
    );

    final data = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 201) {
      await _saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
        data['user'] as Map<String, dynamic>,
      );
      return data;
    } else {
      throw AuthException(
        message: data['error'] as String? ?? 'Signup failed',
        statusCode: response.statusCode,
      );
    }
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  /// Login with email and password.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/login'),
      headers: _headers,
      body: json.encode({
        'email': email,
        'password': password,
      }),
    );

    final data = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      await _saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
        data['user'] as Map<String, dynamic>,
      );
      return data;
    } else {
      throw AuthException(
        message: data['error'] as String? ?? 'Login failed',
        statusCode: response.statusCode,
      );
    }
  }

  // ─── Google Sign-In ────────────────────────────────────────────────────────

  /// Authenticate with Google (sends email + name to backend).
  Future<Map<String, dynamic>> googleSignIn({
    required String email,
    required String fullName,
    String? avatarUrl,
    String? idToken,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/google'),
      headers: _headers,
      body: json.encode({
        'email': email,
        'fullName': fullName,
        'avatarUrl': avatarUrl ?? '',
        'idToken': idToken ?? '',
      }),
    );

    final data = json.decode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      await _saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
        data['user'] as Map<String, dynamic>,
      );
      return data;
    } else {
      throw AuthException(
        message: data['error'] as String? ?? 'Google sign-in failed',
        statusCode: response.statusCode,
      );
    }
  }

  // ─── Token Refresh ─────────────────────────────────────────────────────────

  /// Refresh the access token using the stored refresh token.
  Future<void> refreshToken() async {
    if (_refreshToken == null) {
      throw AuthException(message: 'No refresh token available', statusCode: 401);
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/refresh'),
      headers: _headers,
      body: json.encode({'refreshToken': _refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      await _saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
        data['user'] as Map<String, dynamic>,
      );
    } else {
      await _clearTokens();
      throw AuthException(
        message: 'Session expired. Please log in again.',
        statusCode: response.statusCode,
      );
    }
  }

  // ─── Logout ────────────────────────────────────────────────────────────────

  /// Logout — revokes refresh token on server and clears local storage.
  Future<void> logout() async {
    try {
      if (_refreshToken != null) {
        await http.post(
          Uri.parse('$_baseUrl/api/v1/auth/logout'),
          headers: _headers,
          body: json.encode({'refreshToken': _refreshToken}),
        );
      }
    } catch (e) {
      debugPrint('[Auth] Logout API call failed (continuing): $e');
    }

    await _clearTokens();
  }

  // ─── Forgot Password ──────────────────────────────────────────────────────

  /// Send a password reset request.
  Future<void> forgotPassword(String email) async {
    await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/forgot-password'),
      headers: _headers,
      body: json.encode({'email': email}),
    );
    // Always succeeds (prevents email enumeration)
  }

  // ─── Reset Password ───────────────────────────────────────────────────────

  /// Reset password with a token.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/auth/reset-password'),
      headers: _headers,
      body: json.encode({
        'token': token,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      throw AuthException(
        message: data['error'] as String? ?? 'Password reset failed',
        statusCode: response.statusCode,
      );
    }
  }

  // ─── Get Me ────────────────────────────────────────────────────────────────

  /// Get current authenticated user info from JWT.
  Future<Map<String, dynamic>> getMe() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/auth/me'),
      headers: authHeaders,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      // Try refresh
      try {
        await refreshToken();
        return getMe();
      } catch (_) {
        await _clearTokens();
        throw AuthException(message: 'Session expired', statusCode: 401);
      }
    } else {
      throw AuthException(
        message: 'Failed to get user info',
        statusCode: response.statusCode,
      );
    }
  }
}

/// Custom exception for authentication errors.
class AuthException implements Exception {
  final String message;
  final int statusCode;

  const AuthException({required this.message, required this.statusCode});

  @override
  String toString() => 'AuthException($statusCode): $message';
}
