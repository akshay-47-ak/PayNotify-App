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

  static String currentPaymentId = "";

  static void setCurrentPaymentId(String paymentId) {
    currentPaymentId = paymentId.trim();
  }

  static bool isLikelyPaymentNotification(PaymentNotification notification) {
    final content = [
      notification.title,
      notification.text,
      notification.subText ?? "",
      notification.bigText ?? "",
    ].join(" ").toLowerCase();

    final isKnownPaymentApp =
        paymentPackages.contains(notification.packageName);

    final strongMatch = strongKeywords.any((k) => content.contains(k));
    final weakMatchCount =
        weakKeywords.where((k) => content.contains(k)).length;

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
      r'([A-Z0-9]+(?:-[A-Z0-9]+)*-TXN(?:-[A-Z0-9]+)*|TXN[0-9A-Z\-_]+)',
      caseSensitive: false,
    );

    final match = regex.firstMatch(text);
    if (match == null) {
      return null;
    }

    return match.group(0)?.trim();
  }

  static Future<Map<String, dynamic>> processNotification(
    PaymentNotification notification,
  ) async {
    print("STEP 1 - processNotification entered");
    print("STEP 2 - active currentPaymentId = '$currentPaymentId'");

    final likely = isLikelyPaymentNotification(notification);
    print("STEP 3 - isLikelyPaymentNotification = $likely");

    if (!likely) {
      print("STEP 4 - Rejected by filter, returning false");
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

    print("STEP 5 - message = '$message'");
    print("STEP 6 - fullText = '$fullText'");

    final txnRef = extractTxnRef(fullText);
    print("STEP 7 - extracted txnRef = '$txnRef'");

    if (txnRef == null || txnRef.isEmpty) {
      print("STEP 8 - txnRef not found");
      return {
        "sent": false,
        "status": "TRANSACTION_REF_NOT_FOUND",
        "message": message,
      };
    }

    final request = PaymentNotifyRequest(
      packageName: notification.packageName,
      title: notification.title,
      message: message,
      transactionRef: txnRef,
    );

    print("STEP 9 - request = ${request.toJson()}");

    final response = await ApiService.sendPaymentNotification(request);
    print("STEP 10 - API response = $response");

    if (response == null) {
      return {
        "sent": false,
        "status": "API_ERROR",
        "transactionRef": txnRef,
        "message": message,
      };
    }

    final data = response["data"] is Map<String, dynamic>
        ? response["data"] as Map<String, dynamic>
        : <String, dynamic>{};

    return {
      "sent": true,
      "status": (data["status"] ?? "UNKNOWN").toString(),
      "paymentId": (data["paymentId"] ?? "").toString(),
      "transactionRef":
          (data["transactionRef"] ?? txnRef).toString(),
      "matched": data["matched"],
      "message": message,
    };
  }
}