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

    final isKnownPaymentApp = paymentPackages.contains(
      notification.packageName,
    );
    final strongMatch = strongKeywords.any((k) => content.contains(k));
    final weakMatchCount = weakKeywords
        .where((k) => content.contains(k))
        .length;

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

  static double? extractAmount(String text) {
    if (text.trim().isEmpty) {
      return null;
    }

    final regex = RegExp(
      r'(?:rs\.?|inr|₹)\s*([0-9]+(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)|([0-9]+(?:,[0-9]{2,3})*(?:\.[0-9]{1,2})?|[0-9]+(?:\.[0-9]{1,2})?)\s*(?:rs\.?|inr|₹)',
      caseSensitive: false,
    );

    final match = regex.firstMatch(text);
    final raw = (match?.group(1) ?? match?.group(2))?.replaceAll(",", "");
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    return double.tryParse(raw);
  }

  static String? extractPayerName(String text) {
    if (text.trim().isEmpty) {
      return null;
    }

    final regexes = [
      RegExp(
        r'(?:received from|paid by|from)\s+([A-Za-z][A-Za-z .]{1,60})',
        caseSensitive: false,
      ),
      RegExp(
        r'([A-Za-z][A-Za-z .]{1,60})\s+(?:paid you|sent you)',
        caseSensitive: false,
      ),
    ];

    for (final regex in regexes) {
      final match = regex.firstMatch(text);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return value.replaceAll(RegExp(r'\s+'), " ");
      }
    }

    return null;
  }

  static String appNameForPackage(String packageName) {
    switch (packageName) {
      case "com.phonepe.app":
        return "PHONEPE";
      case "com.google.android.apps.nbu.paisa.user":
        return "GOOGLE_PAY";
      case "net.one97.paytm":
        return "PAYTM";
      case "in.org.npci.upiapp":
        return "BHIM";
      default:
        return packageName;
    }
  }

  static String backendLocalDateTime(DateTime value) {
    final local = value.toLocal();
    final iso = local.toIso8601String();
    return iso.endsWith("Z") ? iso.substring(0, iso.length - 1) : iso;
  }

  static Future<Map<String, dynamic>> processNotification(
    PaymentNotification notification,
    DeviceSession? session,
  ) async {
    if (session == null) {
      return {"sent": false, "status": "DEVICE_NOT_REGISTERED"};
    }

    final likely = isLikelyPaymentNotification(notification);
    if (!likely) {
      return {"sent": false, "status": "FILTERED"};
    }

    final message = _buildMessage(notification);
    final fullText = [
      notification.title,
      message,
    ].where((e) => e.trim().isNotEmpty).join(" ").trim();

    final txnRef = extractTxnRef(fullText);
    final amount = extractAmount(fullText);
    final payerName = extractPayerName(fullText);

    final request = PaymentNotifyRequest(
      enterpriseCode: session.enterpriseCode,
      deviceIdentifier: session.deviceIdentifier,
      terminalId: session.terminalId,
      appName: appNameForPackage(notification.packageName),
      packageName: notification.packageName,
      title: notification.title,
      message: message,
      rawTitle: notification.title,
      rawMessage: message,
      amount: amount,
      payerName: payerName,
      extractedTxnId: txnRef,
      notificationReceivedAt: backendLocalDateTime(DateTime.now()),
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
      "notificationId": (data["notificationId"] ?? "").toString(),
      "expectedAmount": (data["expectedAmount"] ?? "").toString(),
      "receivedAmount": (data["receivedAmount"] ?? "").toString(),
      "amountMatched": data["amountMatched"],
      "utr": (data["utr"] ?? "").toString(),
      "amount": amount,
      "payerName": (data["payerName"] ?? payerName ?? "").toString(),
      "message": (data["message"] ?? message).toString(),
    };
  }
}
