class DeviceSession {
  final String enterpriseCode;
  final String enterpriseName;
  final String role;
  final String terminalId;
  final String deviceIdentifier;
  final String deviceName;
  final String token;
  final int? tokenExpiresAt;
  final String tokenType;

  DeviceSession({
    required this.enterpriseCode,
    required this.enterpriseName,
    required this.role,
    required this.terminalId,
    required this.deviceIdentifier,
    required this.deviceName,
    required this.token,
    this.tokenExpiresAt,
    required this.tokenType,
  });

  Map<String, dynamic> toJson() {
    return {
      "enterpriseCode": enterpriseCode,
      "enterpriseName": enterpriseName,
      "role": role,
      "terminalId": terminalId,
      "deviceIdentifier": deviceIdentifier,
      "deviceName": deviceName,
      "token": token,
      "tokenExpiresAt": tokenExpiresAt,
      "tokenType": tokenType,
    };
  }

  factory DeviceSession.fromJson(Map<String, dynamic> json) {
    final tokenExpiresAtValue = json["tokenExpiresAt"];

    return DeviceSession(
      enterpriseCode: (json["enterpriseCode"] ?? "").toString(),
      enterpriseName: (json["enterpriseName"] ?? "").toString(),
      role: (json["role"] ?? "").toString(),
      terminalId: (json["terminalId"] ?? "").toString(),
      deviceIdentifier: (json["deviceIdentifier"] ?? "").toString(),
      deviceName: (json["deviceName"] ?? "").toString(),
      token: (json["token"] ?? "").toString(),
      tokenExpiresAt: tokenExpiresAtValue is int
          ? tokenExpiresAtValue
          : int.tryParse((tokenExpiresAtValue ?? "").toString()),
      tokenType: (json["tokenType"] ?? "Bearer").toString(),
    );
  }
}
