// lib/services/auth_service.dart
// Uses shared_preferences instead of flutter_secure_storage to avoid
// native setup complexity. Swap back to secure storage if needed.
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _tokenKey    = 'jwt_token';
  static const _nameKey     = 'user_name';
  static const _usernameKey = 'username';

  static Future<void> saveSession(String token, String name, String username) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_tokenKey,    token);
    await p.setString(_nameKey,     name);
    await p.setString(_usernameKey, username);
  }

  static Future<String?> getToken()    async => (await SharedPreferences.getInstance()).getString(_tokenKey);
  static Future<String?> getName()     async => (await SharedPreferences.getInstance()).getString(_nameKey);
  static Future<String?> getUsername() async => (await SharedPreferences.getInstance()).getString(_usernameKey);

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async => (await SharedPreferences.getInstance()).clear();
}