import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/parsed_payment_notification.dart';

class ApiService {
  static const String baseUrl = "https://webhook.site/fd81279e-3822-4cea-9a37-46a271146fe4";
  static const String endpoint = "";

  static Future<bool> sendParsedNotification(
    ParsedPaymentNotification notification,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl$endpoint"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(notification.toJson()),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      print("API send error: $e");
      return false;
    }
  }
}