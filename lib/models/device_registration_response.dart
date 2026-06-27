class DeviceRegistrationResponse {
  final int deviceId;
  final String enterpriseCode;
  final String enterpriseName;
  final String role;
  final String terminalId;
  final String deviceIdentifier;
  final String deviceName;
  final String status;

  DeviceRegistrationResponse({
    required this.deviceId,
    required this.enterpriseCode,
    required this.enterpriseName,
    required this.role,
    required this.terminalId,
    required this.deviceIdentifier,
    required this.deviceName,
    required this.status,
  });

  factory DeviceRegistrationResponse.fromJson(Map<String, dynamic> json) {
    return DeviceRegistrationResponse(
      deviceId: json["deviceId"] ?? 0,
      enterpriseCode: (json["enterpriseCode"] ?? "").toString(),
      enterpriseName: (json["enterpriseName"] ?? "").toString(),
      role: (json["role"] ?? "").toString(),
      terminalId: (json["terminalId"] ?? "").toString(),
      deviceIdentifier: (json["deviceIdentifier"] ?? "").toString(),
      deviceName: (json["deviceName"] ?? "").toString(),
      status: (json["status"] ?? "").toString(),
    );
  }
}
