class EnterpriseValidationResponse {
  final bool valid;
  final String enterpriseCode;
  final String enterpriseName;
  final String status;
  final String message;

  EnterpriseValidationResponse({
    required this.valid,
    required this.enterpriseCode,
    required this.enterpriseName,
    required this.status,
    required this.message,
  });

  factory EnterpriseValidationResponse.fromJson(Map<String, dynamic> json) {
    return EnterpriseValidationResponse(
      valid: json["valid"] == true,
      enterpriseCode: (json["enterpriseCode"] ?? "").toString(),
      enterpriseName: (json["enterpriseName"] ?? "").toString(),
      status: (json["status"] ?? "").toString(),
      message: (json["message"] ?? "").toString(),
    );
  }
}