class PaymentNotifyRequest {
  final String enterpriseCode;
  final String deviceIdentifier;
  final String terminalId;
  final String appName;
  final String packageName;
  final String title;
  final String message;
  final String rawTitle;
  final String rawMessage;
  final double? amount;
  final String? payerName;
  final String? extractedTxnId;
  final String notificationReceivedAt;
  final String? transactionRef;

  PaymentNotifyRequest({
    required this.enterpriseCode,
    required this.deviceIdentifier,
    required this.terminalId,
    required this.appName,
    required this.packageName,
    required this.title,
    required this.message,
    required this.rawTitle,
    required this.rawMessage,
    this.amount,
    this.payerName,
    this.extractedTxnId,
    required this.notificationReceivedAt,
    this.transactionRef,
  });

  Map<String, dynamic> toJson() {
    return {
      "enterpriseCode": enterpriseCode,
      "deviceIdentifier": deviceIdentifier,
      "terminalId": terminalId,
      "appName": appName,
      "packageName": packageName,
      "title": title,
      "message": message,
      "rawTitle": rawTitle,
      "rawMessage": rawMessage,
      "amount": amount,
      "payerName": payerName,
      "extractedTxnId": extractedTxnId,
      "notificationReceivedAt": notificationReceivedAt,
      "transactionRef": transactionRef,
    };
  }
}
