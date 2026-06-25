class DeviceLoginRequest {
  final String deviceName;
  final String password;

  DeviceLoginRequest({required this.deviceName, required this.password});

  Map<String, dynamic> toJson() {
    return {"deviceName": deviceName, "password": password};
  }
}
