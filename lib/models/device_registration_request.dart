class DeviceRegistrationRequest {
  final String enterpriseCode;
  final String role;
  final String deviceIdentifier;
  final String deviceName;

  DeviceRegistrationRequest({
    required this.enterpriseCode,
    required this.role,
    required this.deviceIdentifier,
    required this.deviceName,
  });

  Map<String, dynamic> toJson() {
    return {
      "enterpriseCode": enterpriseCode,
      "role": role,
      "deviceIdentifier": deviceIdentifier,
      "deviceName": deviceName,
    };
  }
}