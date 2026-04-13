class PaymentNotifyRequest {
  final String paymentId;
  final String packageName;
  final String title;
  final String message;

  PaymentNotifyRequest({
    required this.paymentId,
    required this.packageName,
    required this.title,
    required this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      "paymentId": paymentId,
      "packageName": packageName,
      "title": title,
      "message": message,
    };
  }
}