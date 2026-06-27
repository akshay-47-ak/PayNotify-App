class DeviceSession {
  final String enterpriseCode;
  final String enterpriseName;
  final String role;
  final String terminalId;
  final String deviceIdentifier;
  final String deviceName;

  DeviceSession({
    required this.enterpriseCode,
    required this.enterpriseName,
    required this.role,
    required this.terminalId,
    required this.deviceIdentifier,
    required this.deviceName,
  });

  Map<String, dynamic> toJson() {
    return {
      "enterpriseCode": enterpriseCode,
      "enterpriseName": enterpriseName,
      "role": role,
      "terminalId": terminalId,
      "deviceIdentifier": deviceIdentifier,
      "deviceName": deviceName,
    };
  }

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      enterpriseCode: (json["enterpriseCode"] ?? "").toString(),
      enterpriseName: (json["enterpriseName"] ?? "").toString(),
      role: (json["role"] ?? "").toString(),
      terminalId: (json["terminalId"] ?? "").toString(),
      deviceIdentifier: (json["deviceIdentifier"] ?? "").toString(),
      deviceName: (json["deviceName"] ?? "").toString(),
    );
  }
}
