import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

// ── Custom exception ─────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override String toString() => message;
}

// ── API Service ──────────────────────────────────────────────────────
class ApiService {

  static const _jsonHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── Auth ─────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login'),
        headers: _jsonHeaders,
        body: jsonEncode({'username': username, 'password': password}),
      ).timeout(ApiConfig.timeout);

      // Redirect means Flask treated it as browser — not JSON
      if (res.statusCode == 302 || res.statusCode == 301) {
        throw ApiException('Server redirected. Make sure you replaced app.py with the fixed version.');
      }

      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        throw ApiException('Server returned HTML instead of JSON. Replace app.py with the fixed version.');
      }
    } on ApiException { rethrow; }
    catch (e) {
      throw ApiException('Cannot reach server at ${ApiConfig.baseUrl}. Is Flask running?');
    }
  }

  static Future<Map<String, dynamic>> register(String name, String username, String password) async {
    try {
      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/register'),
        headers: _jsonHeaders,
        body: jsonEncode({'name': name, 'username': username, 'password': password}),
      ).timeout(ApiConfig.timeout);
      try {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        throw ApiException('Server returned unexpected response.');
      }
    } on ApiException { rethrow; }
    catch (e) {
      throw ApiException('Cannot reach server at ${ApiConfig.baseUrl}. Is Flask running?');
    }
  }

  // ── Live status ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getStatus({String? token}) async {
    try {
      final headers = Map<String, String>.from(_jsonHeaders);
      if (token != null) headers['Authorization'] = 'Bearer $token';
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/get_status'),
        headers: headers,
      ).timeout(ApiConfig.timeout);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) { return null; }
  }

  // ── History ──────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getHistory(String token, {int limit = 30}) async {
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/history?limit=$limit'),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.timeout);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List) return decoded.cast<Map<String, dynamic>>();
        if (decoded is Map && decoded['readings'] != null) {
          return (decoded['readings'] as List).cast<Map<String, dynamic>>();
        }
      }
      throw ApiException('Failed to load history (${res.statusCode})');
    } on ApiException { rethrow; }
    catch (e) { throw ApiException('Cannot reach server. Is Flask running?'); }
  }

  // ── Connection test ──────────────────────────────────────────────
  static Future<bool> testConnection() async {
    try {
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/get_status'))
          .timeout(const Duration(seconds: 5));
      return res.statusCode == 200 || res.statusCode == 401;
    } catch (_) { return false; }
  }

  /// Tests a URL without touching ApiConfig or SharedPreferences.
  /// Used during auto-scan to avoid triggering unnecessary rebuilds.
  static Future<bool> testConnectionWithUrl(String url) async {
    try {
      final res = await http.get(Uri.parse('$url/get_status'))
          .timeout(const Duration(milliseconds: 600));
      return res.statusCode == 200 || res.statusCode == 401;
    } catch (_) { return false; }
  }
}