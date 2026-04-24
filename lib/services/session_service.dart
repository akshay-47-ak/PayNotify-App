import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_session.dart';

class SessionService {
  static const String _sessionKey = "device_session";
  static const String _deviceIdKey = "local_device_identifier";

  static Future<void> saveSession(DeviceSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  static Future<DeviceSession?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final map = jsonDecode(raw) as Map<String, dynamic>;
    return DeviceSession.fromJson(map);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  static Future<String> getOrCreateLocalDeviceIdentifier() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_deviceIdKey);

    if (existing != null && existing.trim().isNotEmpty) {
      return existing;
    }

    final value =
        "DEVICE-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}";
    await prefs.setString(_deviceIdKey, value);
    return value;
  }
}