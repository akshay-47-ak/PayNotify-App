class DeviceRegistrationRequest {
  final String enterpriseCode;
  final String role;
  final String deviceIdentifier;
  final String deviceName;
  final String password;

  DeviceRegistrationRequest({
    required this.enterpriseCode,
    required this.role,
    required this.deviceIdentifier,
    required this.deviceName,
    required this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      "enterpriseCode": enterpriseCode,
      "role": role,
      "deviceIdentifier": deviceIdentifier,
      "deviceName": deviceName,
      "password": password,
    };
  }
}
