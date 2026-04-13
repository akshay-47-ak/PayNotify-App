import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/payment_notify_request.dart';

class ApiService {
  static const String baseUrl = "http://172.16.2.170:8080";
  static const String endpoint = "/api/payment/notify";

  static Future<bool> sendPaymentNotification(
    PaymentNotifyRequest request,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(request.toJson()),
      );

      print("Notify API status: ${response.statusCode}");
      print("Notify API body: ${response.body}");

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print("API send error: $e");
      return false;
    }
  }
}