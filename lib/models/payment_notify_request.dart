class PaymentNotifyRequest {
  final String packageName;
  final String title;
  final String message;
  final String? transactionRef;

  PaymentNotifyRequest({
    required this.packageName,
    required this.title,
    required this.message,
    this.transactionRef,
  });

  Map<String, dynamic> toJson() {
    return {
      "packageName": packageName,
      "title": title,
      "message": message,
      "transactionRef": transactionRef,
    };
  }
}