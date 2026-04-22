import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/device_registration_request.dart';
import '../models/enterprise_validation_request.dart';
import '../models/payment_notify_request.dart';

class ApiService {
  static const String baseUrl = "http://172.16.2.170:8080";

  static Future<Map<String, dynamic>?> validateEnterprise(
    EnterpriseValidationRequest request,
  ) async {
    return _post("/api/enterprise/validate", request.toJson());
  }

  static Future<Map<String, dynamic>?> registerDevice(
    DeviceRegistrationRequest request,
  ) async {
    return _post("/api/device/register", request.toJson());
  }

  static Future<Map<String, dynamic>?> sendPaymentNotification(
    PaymentNotifyRequest request,
  ) async {
    return _post("/api/payment/notify", request.toJson());
  }

  static Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      print("API $endpoint status: ${response.statusCode}");
      print("API $endpoint body: ${response.body}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    } catch (e) {
      print("API error for $endpoint: $e");
      return null;
    }
  }
}