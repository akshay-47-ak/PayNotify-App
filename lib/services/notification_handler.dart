import '../models/device_session.dart';
import '../models/payment_notification.dart';
import '../models/payment_notify_request.dart';
import 'api_service.dart';

class NotificationHandler {
  static final List<String> paymentPackages = [
    "com.phonepe.app",
    "com.google.android.apps.nbu.paisa.user",
    "net.one97.paytm",
    "in.org.npci.upiapp",
  ];

  static final List<String> strongKeywords = [
    "credited",
    "debited",
    "payment received",
    "payment of",
    "money received",
    "received from",
    "sent to",
    "upi txn",
    "transaction id",
    "utr",
    "ref no",
    "bank account",
    "available balance",
    "credited to your account",
    "debited from your account",
    "paid you",
    "payment of rs",
    "received in bank",
    "bank transfer received",
    "collected from",
  ];

  static final List<String> weakKeywords = [
    "upi",
    "payment",
    "paid",
    "received",
    "sent",
    "transaction",
    "bank",
    "account",
    "₹",
    "rs",
    "inr",
  ];

  static bool isLikelyPaymentNotification(PaymentNotification notification) {
    final content = [
      notification.title,
      notification.text,
      notification.subText ?? "",
      notification.bigText ?? "",
    ].join(" ").toLowerCase();

    final isKnownPaymentApp = paymentPackages.contains(notification.packageName);
    final strongMatch = strongKeywords.any((k) => content.contains(k));
    final weakMatchCount = weakKeywords.where((k) => content.contains(k)).length;

    if (isKnownPaymentApp && (strongMatch || weakMatchCount >= 2)) {
      return true;
    }

    if (!isKnownPaymentApp && strongMatch && weakMatchCount >= 2) {
      return true;
    }

    return false;
  }

  static String _buildMessage(PaymentNotification notification) {
    final parts = <String>[];
    final seen = <String>{};

    void addPart(String? value) {
      final v = (value ?? "").trim();
      if (v.isEmpty) return;

      final normalized = v.toLowerCase();
      if (seen.contains(normalized)) return;

      seen.add(normalized);
      parts.add(v);
    }

    addPart(notification.text);
    addPart(notification.subText);
    addPart(notification.bigText);

    return parts.join(" ").trim();
  }

  static String? extractTxnRef(String text) {
    if (text.trim().isEmpty) {
      return null;
    }

    final regex = RegExp(
      r'([A-Z0-9]+(?:-[A-Z0-9]+)*-TXN(?:-[A-Z0-9]+)*|TXN[0-9A-Z\-_]+|PADM-TXN-[A-Z0-9\-_]+)',
      caseSensitive: false,
    );

    final match = regex.firstMatch(text);
    return match?.group(0)?.trim();
  }

  static Future<Map<String, dynamic>> processNotification(
    PaymentNotification notification,
    DeviceSession? session,
  ) async {
    if (session == null) {
      return {
        "sent": false,
        "status": "DEVICE_NOT_REGISTERED",
      };
    }

    final likely = isLikelyPaymentNotification(notification);
    if (!likely) {
      return {
        "sent": false,
        "status": "FILTERED",
      };
    }

    final message = _buildMessage(notification);
    final fullText = [
      notification.title,
      message,
    ].where((e) => e.trim().isNotEmpty).join(" ").trim();

    final txnRef = extractTxnRef(fullText);

    final request = PaymentNotifyRequest(
      enterpriseCode: session.enterpriseCode,
      deviceIdentifier: session.deviceIdentifier,
      packageName: notification.packageName,
      title: notification.title,
      message: message,
      transactionRef: txnRef,
    );

    final response = await ApiService.sendPaymentNotification(request);

    if (response == null) {
      return {
        "sent": false,
        "status": "API_ERROR",
        "transactionRef": txnRef,
        "message": message,
      };
    }

    final apiSuccess = response["success"] == true;
    final apiMessage = (response["message"] ?? "").toString();

    if (!apiSuccess) {
      return {
        "sent": false,
        "status": "BACKEND_ERROR",
        "transactionRef": txnRef,
        "message": apiMessage.isEmpty ? message : apiMessage,
      };
    }

    final data = response["data"] is Map<String, dynamic>
        ? response["data"] as Map<String, dynamic>
        : <String, dynamic>{};

    return {
      "sent": true,
      "status": (data["status"] ?? "UNKNOWN").toString(),
      "paymentId": (data["paymentId"] ?? "").toString(),
      "transactionRef": (data["transactionRef"] ?? txnRef ?? "").toString(),
      "matched": data["matched"],
      "message": (data["message"] ?? message).toString(),
    };
  }
}