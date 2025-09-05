import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:HPGM/Services/token_storage.dart';
import 'package:HPGM/login.dart';
import 'package:HPGM/services/cache_service.dart';

/// Comprehensive authentication manager that handles token validation,
/// refresh, and automatic login redirects
class AuthManager {
  static bool _isValidating = false;

  /// Make authenticated HTTP request with automatic token handling
  static Future<http.Response?> authenticatedRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    dynamic body,
    BuildContext? context,
  }) async {
    try {
      // First, ensure we have a valid token
      final hasValidToken = await ensureValidToken(context: context);
      if (!hasValidToken) {
        print('❌ No valid token available');
        return null;
      }

      final token = await TokenStorage.getToken();
      if (token == null) {
        print('❌ Token is null after validation');
        return null;
      }

      // Prepare headers
      final requestHeaders = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        ...?headers,
      };

      // Make the request
      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(Uri.parse(url), headers: requestHeaders)
              .timeout(Duration(seconds: 30));
          break;
        case 'POST':
          response = await http
              .post(
                Uri.parse(url),
                headers: requestHeaders,
                body: body is String ? body : jsonEncode(body),
              )
              .timeout(Duration(seconds: 30));
          break;
        case 'PUT':
          response = await http
              .put(
                Uri.parse(url),
                headers: requestHeaders,
                body: body is String ? body : jsonEncode(body),
              )
              .timeout(Duration(seconds: 30));
          break;
        case 'DELETE':
          response = await http
              .delete(Uri.parse(url), headers: requestHeaders)
              .timeout(Duration(seconds: 30));
          break;
        default:
          throw UnsupportedError('HTTP method $method not supported');
      }

      // Handle response
      if (response.statusCode == 401) {
        print('🔄 Got 401, attempting token refresh...');

        // Try to refresh token
        final refreshSuccess = await TokenStorage.refreshToken();
        if (refreshSuccess) {
          print('✅ Token refreshed, retrying request...');
          // Retry the request with new token
          return await authenticatedRequest(
            method: method,
            url: url,
            headers: headers,
            body: body,
            context: context,
          );
        } else {
          print('❌ Token refresh failed, redirecting to login');
          await _handleAuthenticationFailure(context);
          return null;
        }
      }

      return response;
    } catch (e) {
      print('❌ Authenticated request failed: $e');
      return null;
    }
  }

  /// Convenient methods for different HTTP verbs
  static Future<http.Response?> get(
    String url, {
    BuildContext? context,
    Map<String, String>? headers,
  }) {
    return authenticatedRequest(
      method: 'GET',
      url: url,
      context: context,
      headers: headers,
    );
  }

  static Future<http.Response?> post(
    String url, {
    dynamic body,
    BuildContext? context,
    Map<String, String>? headers,
  }) {
    return authenticatedRequest(
      method: 'POST',
      url: url,
      body: body,
      context: context,
      headers: headers,
    );
  }

  static Future<http.Response?> put(
    String url, {
    dynamic body,
    BuildContext? context,
    Map<String, String>? headers,
  }) {
    return authenticatedRequest(
      method: 'PUT',
      url: url,
      body: body,
      context: context,
      headers: headers,
    );
  }

  static Future<http.Response?> delete(
    String url, {
    BuildContext? context,
    Map<String, String>? headers,
  }) {
    return authenticatedRequest(
      method: 'DELETE',
      url: url,
      context: context,
      headers: headers,
    );
  }

  /// Ensure we have a valid token (validate and refresh if needed)
  static Future<bool> ensureValidToken({BuildContext? context}) async {
    if (_isValidating) {
      // Wait for current validation to complete
      while (_isValidating) {
        await Future.delayed(Duration(milliseconds: 100));
      }
      return await TokenStorage.isLoggedIn();
    }

    _isValidating = true;

    try {
      // Check if user is logged in
      if (!await TokenStorage.isLoggedIn()) {
        print('❌ User not logged in');
        await _handleAuthenticationFailure(context);
        return false;
      }

      // Check if token is expired based on timestamp
      if (await TokenStorage.isTokenExpired()) {
        print('⏰ Token expired based on timestamp, attempting refresh...');

        final refreshSuccess = await TokenStorage.refreshToken();
        if (refreshSuccess) {
          print('✅ Token refreshed successfully');
          return true;
        } else {
          print('❌ Token refresh failed');
          await _handleAuthenticationFailure(context);
          return false;
        }
      }

      // Skip server validation - rely on timestamp-based expiry
      // and let actual API calls handle 401 responses naturally
      /*
      // Validate token with server (only when online)
      if (await CacheService.isOnline()) {
        final isValid = await TokenStorage.validateTokenWithServer();
        if (!isValid) {
          print('❌ Server validation failed, attempting refresh...');

          final refreshSuccess = await TokenStorage.refreshToken();
          if (refreshSuccess) {
            print('✅ Token refreshed after validation failure');
            return true;
          } else {
            print('❌ Token refresh failed after validation failure');
            await _handleAuthenticationFailure(context);
            return false;
          }
        }
      }
      */

      print('✅ Token is valid');
      return true;
    } finally {
      _isValidating = false;
    }
  }

  /// Validate token on app startup
  static Future<void> validateOnStartup() async {
    try {
      print('🚀 Validating authentication on app startup...');

      if (!await TokenStorage.isLoggedIn()) {
        print('ℹ️ User not logged in');
        return;
      }

      // Only validate with server if online
      if (await CacheService.isOnline()) {
        await ensureValidToken();
      } else {
        print('📱 Offline - skipping server token validation');
      }
    } catch (e) {
      print('❌ Startup token validation error: $e');
    }
  }

  /// Handle authentication failure by clearing tokens and redirecting to login
  static Future<void> _handleAuthenticationFailure(
    BuildContext? context,
  ) async {
    print('🚪 Handling authentication failure...');

    // Clear all stored tokens
    await TokenStorage.clearLoginData();

    // Show user notification if context is available
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🔐 Session expired. Please log in again.',
            style: TextStyle(fontFamily: "Sans"),
          ),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: 4),
        ),
      );

      // Redirect to login screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    }
  }

  /// Logout user and clear all data
  static Future<void> logout({BuildContext? context}) async {
    print('👋 User logging out...');

    await TokenStorage.clearLoginData();
    await CacheService.clearCache();

    if (context != null && context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    }
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    return await TokenStorage.isLoggedIn();
  }
}
