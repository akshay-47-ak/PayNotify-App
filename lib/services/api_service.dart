import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/payment_notify_request.dart';

class ApiService {
  static const String baseUrl = "http://172.16.2.170:8080";
  static const String notifyEndpoint = "/api/payment/notify";

  static Future<Map<String, dynamic>?> sendPaymentNotification(
    PaymentNotifyRequest request,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl$notifyEndpoint"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(request.toJson()),
      );

      print("Notify API status: ${response.statusCode}");
      print("Notify API body: ${response.body}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return null;
    } catch (e) {
      print("API send error: $e");
      return null;
    }
  }
}