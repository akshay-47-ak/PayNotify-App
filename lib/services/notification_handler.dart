import '../models/payment_notification.dart';
import 'api_service.dart';
import 'payment_parser.dart';

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
    if (!isLikelyPaymentNotification(notification)) {
      return false;
    }

    final parsed = PaymentParser.parse(notification);
    return await ApiService.sendParsedNotification(parsed);
  }
}