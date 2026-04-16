// import '../models/payment_notification.dart';
// import '../models/parsed_payment_notification.dart';

// class PaymentParser {
//   static ParsedPaymentNotification parse(PaymentNotification notification) {
//     final rawContent = [
//       notification.title,
//       notification.text,
//       notification.subText ?? "",
//       notification.bigText ?? "",
//     ].join(" ").trim();

//     return ParsedPaymentNotification(
//       packageName: notification.packageName,
//       appName: notification.appName,
//       title: notification.title,
//       text: notification.text,
//       rawContent: rawContent,
//       transactionType: _extractTransactionType(rawContent),
//       partyName: _extractPartyName(rawContent),
//       referenceId: _extractReferenceId(rawContent),
//       amount: _extractAmount(rawContent),
//       timestamp: notification.timestamp,
//     );
//   }

//   static String? _extractTransactionType(String text) {
//     final t = text.toLowerCase();

//     if (t.contains("received") || t.contains("credited")) {
//       return "received";
//     }
//     if (t.contains("sent") || t.contains("debited") || t.contains("paid")) {
//       return "sent";
//     }
//     return null;
//   }

//   static double? _extractAmount(String text) {
//     final regex = RegExp(
//       r'(₹|rs\.?|inr)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
//       caseSensitive: false,
//     );
//     final match = regex.firstMatch(text);

//     if (match != null) {
//       final amountStr = match.group(2)?.replaceAll(',', '');
//       if (amountStr != null) {
//         return double.tryParse(amountStr);
//       }
//     }
//     return null;
//   }

//   static String? _extractReferenceId(String text) {
//     final regex = RegExp(
//       r'(utr|ref(?:erence)?(?: no)?|txn(?: id)?)[:\s\-]*([A-Za-z0-9\-]{6,})',
//       caseSensitive: false,
//     );
//     final match = regex.firstMatch(text);
//     return match?.group(2);
//   }

//   static String? _extractPartyName(String text) {
//     final patterns = [
//       RegExp(r'received from\s+([A-Za-z0-9 ._-]+)', caseSensitive: false),
//       RegExp(r'sent to\s+([A-Za-z0-9 ._-]+)', caseSensitive: false),
//       RegExp(r'paid to\s+([A-Za-z0-9 ._-]+)', caseSensitive: false),
//     ];

//     for (final pattern in patterns) {
//       final match = pattern.firstMatch(text);
//       if (match != null) {
//         return match.group(1)?.trim();
//       }
//     }
//     return null;
//   }
// }