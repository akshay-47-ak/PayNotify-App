class PaymentNotification {
  final String packageName;
  final String title;
  final String text;
  final String? subText;
  final String? bigText;

  PaymentNotification({
    required this.packageName,
    required this.title,
    required this.text,
    this.subText,
    this.bigText,
  });

  factory PaymentNotification.fromMap(Map<dynamic, dynamic> map) {
    return PaymentNotification(
      packageName: (map["packageName"] ?? "").toString(),
      title: (map["title"] ?? "").toString(),
      text: (map["text"] ?? "").toString(),
      subText: map["subText"]?.toString(),
      bigText: map["bigText"]?.toString(),
    );
  }
}