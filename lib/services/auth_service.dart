import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

/// AuthService handles JWT-based authentication, token storage,
/// forgot password, and reset password flows via the PHP API.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const String _baseUrl = 'http://localhost/kurnia_api/api.php';
  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'logged_in_user';

  String? _cachedToken;
  Map<String, dynamic>? _cachedUser;

  /// Get the stored JWT token
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  /// Save JWT token to local storage
  Future<void> _saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Save user data to local storage
  Future<void> _saveUser(Map<String, dynamic> user) async {
    _cachedUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }

  /// Get cached user data
  Future<Map<String, dynamic>?> getCachedUser() async {
    if (_cachedUser != null) return _cachedUser;
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      _cachedUser = jsonDecode(userStr);
    }
    return _cachedUser;
  }

  /// Clear all auth data (logout)
  Future<void> logout() async {
    _cachedToken = null;
    _cachedUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  /// Check if user is logged in with a valid token
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token == null) return false;

    if (kIsWeb) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl?action=verify_token'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          return res['valid'] == true;
        }
      } catch (e) {
        debugPrint('Token verification error: $e');
      }
    }
    return false;
  }

  /// Login with JWT - returns AppUser on success, null on failure
  /// Also stores the JWT token locally.
  Future<Map<String, dynamic>?> loginWithJwt(String username, String password) async {
    if (kIsWeb) {
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl?action=login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        );
        if (response.statusCode == 200) {
          final res = jsonDecode(response.body);
          if (res['status'] == 'success') {
            await _saveToken(res['token']);
            await _saveUser(res['user']);
            return res['user'];
          } else {
            return null;
          }
        }
      } catch (e) {
        debugPrint('JWT login error: $e');
      }
    }
    return null;
  }

  /// Forgot Password - send username + email to verify identity
  /// Returns a map with reset_token on success, or error message on failure.
  Future<Map<String, dynamic>> forgotPassword(String username, String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=forgot_password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'email': email}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Forgot password error: $e');
    }
    return {'status': 'error', 'message': 'Gagal terhubung ke server'};
  }

  /// Reset Password - use reset_token + new_password
  Future<Map<String, dynamic>> resetPassword(String resetToken, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?action=reset_password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reset_token': resetToken, 'new_password': newPassword}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Reset password error: $e');
    }
    return {'status': 'error', 'message': 'Gagal terhubung ke server'};
  }

  /// Get authorization headers with JWT token
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
