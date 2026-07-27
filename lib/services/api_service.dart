import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

import '../models/device_login_request.dart';
import '../models/device_registration_request.dart';
import '../models/enterprise_validation_request.dart';
import '../models/payment_notify_request.dart';

class ApiService {
  static const String baseUrl = "https://briskly-jawline-grief.ngrok-free.dev";

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

  static Future<Map<String, dynamic>?> loginDevice(
    DeviceLoginRequest request,
  ) async {
    return _post("/api/device/login", request.toJson());
  }

  static Future<Map<String, dynamic>?> sendPaymentNotification(
    PaymentNotifyRequest request,
  ) async {
    return _post("/api/payment/notify", request.toJson());
  }

  static Future<Map<String, dynamic>?> manuallyConfirmPayment({
    required String paymentId,
    String? utr,
    String? payerName,
    String? reason,
  }) async {
    return _post(
      "/api/payments/${Uri.encodeComponent(paymentId)}/manual-confirm",
      {"utr": utr, "payerName": payerName, "reason": reason},
    );
  }

  static Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      developer.log(
        "API $endpoint status: ${response.statusCode}",
        name: "ApiService",
      );
      developer.log("API $endpoint body: ${response.body}", name: "ApiService");

      if (response.body.trim().isEmpty) {
        return null;
      }

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        developer.log(
          "API json parse error for $endpoint",
          name: "ApiService",
          error: e,
        );
        return null;
      }
    } catch (e) {
      developer.log("API error for $endpoint", name: "ApiService", error: e);
      return null;
    }
  }
}
