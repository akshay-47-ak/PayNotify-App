class DeviceRegistrationResponse {
  final int deviceId;
  final String enterpriseCode;
  final String enterpriseName;
  final String role;
  final String terminalId;
  final String deviceIdentifier;
  final String deviceName;
  final String status;
  final String token;
  final int? tokenExpiresAt;
  final String tokenType;

  DeviceRegistrationResponse({
    required this.deviceId,
    required this.enterpriseCode,
    required this.enterpriseName,
    required this.role,
    required this.terminalId,
    required this.deviceIdentifier,
    required this.deviceName,
    required this.status,
    required this.token,
    this.tokenExpiresAt,
    required this.tokenType,
  });

  factory DeviceRegistrationResponse.fromJson(Map<String, dynamic> json) {
    final tokenExpiresAtValue = json["tokenExpiresAt"];

    return DeviceRegistrationResponse(
      deviceId: json["deviceId"] ?? 0,
      enterpriseCode: (json["enterpriseCode"] ?? "").toString(),
      enterpriseName: (json["enterpriseName"] ?? "").toString(),
      role: (json["role"] ?? "").toString(),
      terminalId: (json["terminalId"] ?? "").toString(),
      deviceIdentifier: (json["deviceIdentifier"] ?? "").toString(),
      deviceName: (json["deviceName"] ?? "").toString(),
      status: (json["status"] ?? "").toString(),
      token: (json["token"] ?? "").toString(),
      tokenExpiresAt: tokenExpiresAtValue is int
          ? tokenExpiresAtValue
          : int.tryParse((tokenExpiresAtValue ?? "").toString()),
      tokenType: (json["tokenType"] ?? "Bearer").toString(),
    );
  }
}
