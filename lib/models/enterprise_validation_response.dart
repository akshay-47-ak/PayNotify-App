class EnterpriseValidationResponse {
  final bool valid;
  final String enterpriseCode;
  final String enterpriseName;
  final String department;
  final int? departmentCode;
  final String status;
  final String message;
  final String token;
  final int? tokenExpiresAt;
  final String tokenType;

  EnterpriseValidationResponse({
    required this.valid,
    required this.enterpriseCode,
    required this.enterpriseName,
    required this.department,
    this.departmentCode,
    required this.status,
    required this.message,
    required this.token,
    this.tokenExpiresAt,
    required this.tokenType,
  });

  factory EnterpriseValidationResponse.fromJson(Map<String, dynamic> json) {
    final departmentCodeValue = json["departmentCode"];
    final tokenExpiresAtValue = json["tokenExpiresAt"];

    return EnterpriseValidationResponse(
      valid: json["valid"] == true,
      enterpriseCode: (json["enterpriseCode"] ?? "").toString(),
      enterpriseName: (json["enterpriseName"] ?? "").toString(),
      department: (json["department"] ?? "").toString(),
      departmentCode: departmentCodeValue is int
          ? departmentCodeValue
          : int.tryParse((departmentCodeValue ?? "").toString()),
      status: (json["status"] ?? "").toString(),
      message: (json["message"] ?? "").toString(),
      token: (json["token"] ?? "").toString(),
      tokenExpiresAt: tokenExpiresAtValue is int
          ? tokenExpiresAtValue
          : int.tryParse((tokenExpiresAtValue ?? "").toString()),
      tokenType: (json["tokenType"] ?? "Bearer").toString(),
    );
  }
}
