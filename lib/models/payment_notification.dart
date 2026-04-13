class PaymentNotification {
  final String packageName;
  final String appName;
  final String title;
  final String text;
  final String? subText;
  final String? bigText;
  final int timestamp;

  PaymentNotification({
    required this.packageName,
    required this.appName,
    required this.title,
    required this.text,
    this.subText,
    this.bigText,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      "packageName": packageName,
      "appName": appName,
      "title": title,
      "text": text,
      "subText": subText,
      "bigText": bigText,
      "timestamp": timestamp,
    };
  }

  factory PaymentNotification.fromMap(Map<dynamic, dynamic> map) {
    return PaymentNotification(
      packageName: map["packageName"] ?? "",
      appName: map["appName"] ?? "",
      title: map["title"] ?? "",
      text: map["text"] ?? "",
      subText: map["subText"],
      bigText: map["bigText"],
      timestamp: map["timestamp"] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }
}