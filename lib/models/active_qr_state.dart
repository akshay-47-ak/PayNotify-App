class ActiveQrState {
  final String paymentId;
  final String transactionRef;
  final String status;
  final String qrImageBase64;
  final int generatedAtMillis;

  ActiveQrState({
    required this.paymentId,
    required this.transactionRef,
    required this.status,
    required this.qrImageBase64,
    required this.generatedAtMillis,
  });

  Map<String, dynamic> toJson() {
    return {
      "paymentId": paymentId,
      "transactionRef": transactionRef,
      "status": status,
      "qrImageBase64": qrImageBase64,
      "generatedAtMillis": generatedAtMillis,
    };
  }

  factory ActiveQrState.fromJson(Map<String, dynamic> json) {
    final generatedAtValue = json["generatedAtMillis"];

    return ActiveQrState(
      paymentId: (json["paymentId"] ?? "").toString(),
      transactionRef: (json["transactionRef"] ?? "").toString(),
      status: (json["status"] ?? "").toString(),
      qrImageBase64: (json["qrImageBase64"] ?? "").toString(),
      generatedAtMillis: generatedAtValue is int
          ? generatedAtValue
          : int.tryParse((generatedAtValue ?? "").toString()) ?? 0,
    );
  }
}
