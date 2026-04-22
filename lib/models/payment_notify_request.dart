class PaymentNotifyRequest {
  final String enterpriseCode;
  final String deviceIdentifier;
  final String packageName;
  final String title;
  final String message;
  final String? transactionRef;

  PaymentNotifyRequest({
    required this.enterpriseCode,
    required this.deviceIdentifier,
    required this.packageName,
    required this.title,
    required this.message,
    this.transactionRef,
  });

  Map<String, dynamic> toJson() {
    return {
      "enterpriseCode": enterpriseCode,
      "deviceIdentifier": deviceIdentifier,
      "packageName": packageName,
      "title": title,
      "message": message,
      "transactionRef": transactionRef,
    };
  }
}