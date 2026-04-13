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

  static Future<bool> processNotification(
  PaymentNotification notification,
) async {
  print("STEP 1 - processNotification entered");
  print("STEP 2 - currentPaymentId = '$currentPaymentId'");

  if (currentPaymentId.isEmpty) {
    print("STEP 3 - Payment ID empty, returning false");
    return false;
  }

  final likely = isLikelyPaymentNotification(notification);
  print("STEP 4 - isLikelyPaymentNotification = $likely");

  if (!likely) {
    print("STEP 5 - Rejected by filter, returning false");
    return false;
  }

  final message = [
    notification.text,
    notification.subText ?? "",
    notification.bigText ?? "",
  ].where((e) => e.trim().isNotEmpty).join(" ").trim();

  print("STEP 6 - message = '$message'");

  final request = PaymentNotifyRequest(
    paymentId: currentPaymentId,
    packageName: notification.packageName,
    title: notification.title,
    message: message,
  );

  print("STEP 7 - request = ${request.toJson()}");

  final result = await ApiService.sendPaymentNotification(request);
  print("STEP 8 - API result = $result");

  return result;
}
}