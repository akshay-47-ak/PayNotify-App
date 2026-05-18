class DeviceLoginRequest {
  final String enterpriseCode;
  final String deviceIdentifier;

  DeviceLoginRequest({
    required this.enterpriseCode,
    required this.deviceIdentifier,
  });

  Map<String, dynamic> toJson() {
    return {
      "enterpriseCode": enterpriseCode,
      "deviceIdentifier": deviceIdentifier,
    };
  }
}