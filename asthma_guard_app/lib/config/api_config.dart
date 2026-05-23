import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ApiConfig {
  // Dynamic fallback - localhost for development
  static const String _fallbackIp = '10.247.206.127';
  static String _baseUrl = 'http://$_fallbackIp:5000';
  static String? _currentIp;

  static String get baseUrl => _baseUrl;

  /// Get the currently detected/set IP address
  static String? get currentIp => _currentIp;

  /// Load saved IP from storage or auto-detect
  static Future<void> loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('server_ip');

    if (savedIp != null && savedIp.isNotEmpty) {
      _currentIp = savedIp;
      _baseUrl = 'http://$savedIp:5000';
      // ignore: avoid_print
      print('✓ Loaded saved server IP: $savedIp');
      return;
    }

    // Try to auto-detect server IP
    final detectedIp = await _autoDetectServerIp();
    if (detectedIp != null) {
      _currentIp = detectedIp;
      _baseUrl = 'http://$detectedIp:5000';
      await prefs.setString('server_ip', detectedIp);
      // ignore: avoid_print
      print('✓ Auto-detected server IP: $detectedIp');
      return;
    }

    // Fall back
    _currentIp = _fallbackIp;
    _baseUrl = 'http://$_fallbackIp:5000';
    // ignore: avoid_print
    print(
      '⚠ Using fallback: $_fallbackIp. Please configure server IP in settings.',
    );
  }

  /// Auto-detect the server IP by trying to connect to common addresses
  static Future<String?> _autoDetectServerIp() async {
    const port = 5000;

    // Try localhost first (for testing)
    if (await _isServerReachable('localhost', port)) {
      return 'localhost';
    }

    // Try 127.0.0.1
    if (await _isServerReachable('127.0.0.1', port)) {
      return '127.0.0.1';
    }

    // Try to get local IP and test it
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 &&
              !addr.isLoopback &&
              (addr.address.startsWith('10.') ||
                  addr.address.startsWith('192.168.'))) {
            if (await _isServerReachable(addr.address, port)) {
              return addr.address;
            }
          }
        }
      }
    } catch (e) {
      print('Error detecting local network: $e');
    }

    return null;
  }

  /// Check if server is reachable at given address and port
  static Future<bool> _isServerReachable(String host, int port) async {
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Manually update the server IP
  static Future<void> updateIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_ip', ip);
    _currentIp = ip;
    _baseUrl = 'http://$ip:5000';
    print('✓ Server IP updated to: $ip');
  }

  /// Get the currently saved/active IP
  static Future<String> getSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_ip') ?? _fallbackIp;
  }

  /// Get all available local IP addresses for user to choose from
  static Future<List<String>> getAvailableLocalIps() async {
    final ips = <String>['localhost', '127.0.0.1'];

    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            ips.add(addr.address);
          }
        }
      }
    } catch (e) {
      print('Error getting local IPs: $e');
    }

    return ips;
  }

  /// Reset to fallback and clear saved IP
  static Future<void> resetIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server_ip');
    _currentIp = _fallbackIp;
    _baseUrl = 'http://$_fallbackIp:5000';
    print('✓ Reset to fallback IP: $_fallbackIp');
  }

  static const Duration timeout = Duration(seconds: 10);

  static Map<String, String> get jsonHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> headers({String? token}) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };
}
