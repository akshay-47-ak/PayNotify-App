class ParsedPaymentNotification {
  final String packageName;
  final String appName;
  final String title;
  final String text;
  final String rawContent;
  final String? transactionType;
  final String? partyName;
  final String? referenceId;
  final double? amount;
  final int timestamp;

  ParsedPaymentNotification({
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    required this.rawContent,
    this.transactionType,
    this.partyName,
    this.referenceId,
    this.amount,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      "packageName": packageName,
      "appName": appName,
      "title": title,
      "text": text,
      "rawContent": rawContent,
      "transactionType": transactionType,
      "partyName": partyName,
      "referenceId": referenceId,
      "amount": amount,
      "timestamp": timestamp,
    };
  }
}