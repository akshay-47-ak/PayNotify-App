import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/payment_notify_request.dart';

class ApiService {
  static const String baseUrl = "http://172.16.2.170:8080";
  static const String notifyEndpoint = "/api/payment/notify";
  static const String latestPendingEndpoint = "/api/payment/latest-pending";

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
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print("API send error: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchLatestPendingPayment() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl$latestPendingEndpoint"),
      );

      print("Latest pending status: ${response.statusCode}");
      print("Latest pending body: ${response.body}");

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body);
      }

      return null;
    } catch (e) {
      print("Fetch latest pending error: $e");
      return null;
    }
  }
}