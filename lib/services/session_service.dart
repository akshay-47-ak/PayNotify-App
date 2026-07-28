import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/active_qr_state.dart';
import '../models/device_session.dart';

class SessionService {
  static const String _sessionKey = "device_session";
  static const String _deviceIdKey = "local_device_identifier";
  static const String _activeQrPrefix = "active_qr_state_";

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

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return DeviceSession.fromJson(map);
    } catch (e) {
      await prefs.remove(_sessionKey);
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    // This clears only login/session.
    // Do not remove local device identifier,
    // otherwise backend will treat same phone as new device.
    await prefs.remove(_sessionKey);
    for (final key in prefs.getKeys().where(
      (k) => k.startsWith(_activeQrPrefix),
    )) {
      await prefs.remove(key);
    }
  }

  static Future<void> saveActiveQrState(
    String terminalId,
    ActiveQrState state,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeQrKey(terminalId), jsonEncode(state.toJson()));
  }

  static Future<ActiveQrState?> getActiveQrState(String terminalId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeQrKey(terminalId));

    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final state = ActiveQrState.fromJson(map);

      if (state.paymentId.isEmpty || state.qrImageBase64.isEmpty) {
        await clearActiveQrState(terminalId);
        return null;
      }

      return state;
    } catch (e) {
      await clearActiveQrState(terminalId);
      return null;
    }
  }

  static Future<void> clearActiveQrState(String terminalId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeQrKey(terminalId));
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

  static Future<String> buildEnterpriseDeviceIdentifier(
    String enterpriseCode,
  ) async {
    final localDeviceId = await getOrCreateLocalDeviceIdentifier();
    return "${enterpriseCode.trim().toUpperCase()}_$localDeviceId";
  }

  static String _activeQrKey(String terminalId) {
    return "$_activeQrPrefix${terminalId.trim()}";
  }
}
