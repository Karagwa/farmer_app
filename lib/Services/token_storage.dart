import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _loginTimeKey = 'login_time';

  // Save login credentials
  static Future<void> saveLoginData({
    required String token,
    String? userId,
    String? username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_loginTimeKey, DateTime.now().toIso8601String());

    if (userId != null) await prefs.setString(_userIdKey, userId);
    if (username != null) await prefs.setString(_usernameKey, username);
  }

  // Get saved token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Clear all login data (logout)
  static Future<void> clearLoginData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_loginTimeKey);
  }

  // Helper method for testing - reset first time flag
  static Future<void> resetFirstTimeFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstTime', true);
    await clearLoginData();
  }
}
