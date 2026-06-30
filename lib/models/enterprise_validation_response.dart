class EnterpriseValidationResponse {
  final bool valid;
  final String enterpriseCode;
  final String enterpriseName;
  final String department;
  final int? departmentCode;
  final String status;
  final String message;

  EnterpriseValidationResponse({
    required this.valid,
    required this.enterpriseCode,
    required this.enterpriseName,
    required this.department,
    this.departmentCode,
    required this.status,
    required this.message,
  });

  factory EnterpriseValidationResponse.fromJson(Map<String, dynamic> json) {
    final departmentCodeValue = json["departmentCode"];

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
    );
  }
}
