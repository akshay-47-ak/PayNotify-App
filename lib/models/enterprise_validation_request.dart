class EnterpriseValidationRequest {
  final String enterpriseCode;

  EnterpriseValidationRequest({
    required this.enterpriseCode,
  });

  Map<String, dynamic> toJson() {
    return {
      "enterpriseCode": enterpriseCode,
    };
  }
}