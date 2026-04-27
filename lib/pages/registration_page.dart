import 'package:flutter/material.dart';

import '../models/device_registration_request.dart';
import '../models/device_registration_response.dart';
import '../models/device_session.dart';
import '../models/enterprise_validation_request.dart';
import '../models/enterprise_validation_response.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class RegistrationPage extends StatefulWidget {
  final Function(DeviceSession) onRegistered;

  const RegistrationPage({
    super.key,
    required this.onRegistered,
  });

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController enterpriseCodeController =
      TextEditingController();
  final TextEditingController deviceNameController = TextEditingController();

  String selectedRole = "OWNER";
  bool isRegistering = false;
  final List<String> logs = [];

  Future<void> _registerDevice() async {
    final enterpriseCode = enterpriseCodeController.text.trim();
    final deviceName = deviceNameController.text.trim();

    if (enterpriseCode.isEmpty) {
      _showSnackBar("Please enter enterprise code");
      return;
    }

    if (deviceName.isEmpty) {
      _showSnackBar("Please enter device name");
      return;
    }

    setState(() {
      isRegistering = true;
    });

    try {
      final validationResponse = await ApiService.validateEnterprise(
        EnterpriseValidationRequest(enterpriseCode: enterpriseCode),
      );

      if (validationResponse == null ||
          validationResponse["success"] != true ||
          validationResponse["data"] == null) {
        final msg =
            (validationResponse?["message"] ?? "Enterprise validation failed")
                .toString();
        _addLog(msg);
        _showSnackBar(msg);
        return;
      }

      final validationData =
          validationResponse["data"] as Map<String, dynamic>;

      final validationResult =
          EnterpriseValidationResponse.fromJson(validationData);

      if (!validationResult.valid) {
        _addLog(validationResult.message);
        _showSnackBar(validationResult.message);
        return;
      }

      final localDeviceId =
          await SessionService.getOrCreateLocalDeviceIdentifier();

      final deviceIdentifier =
          "${validationResult.enterpriseCode}_$localDeviceId";

      final registerResponse = await ApiService.registerDevice(
        DeviceRegistrationRequest(
          enterpriseCode: validationResult.enterpriseCode,
          role: selectedRole,
          deviceIdentifier: deviceIdentifier,
          deviceName: deviceName,
        ),
      );

      if (registerResponse == null ||
          registerResponse["success"] != true ||
          registerResponse["data"] == null) {
        final msg =
            (registerResponse?["message"] ?? "Device registration failed")
                .toString();
        _addLog(msg);
        _showSnackBar(msg);
        return;
      }

      final registerData = registerResponse["data"] as Map<String, dynamic>;
      final registeredDevice =
          DeviceRegistrationResponse.fromJson(registerData);

      final session = DeviceSession(
        enterpriseCode: registeredDevice.enterpriseCode,
        enterpriseName: registeredDevice.enterpriseName,
        role: registeredDevice.role,
        terminalId: registeredDevice.terminalId,
        deviceIdentifier: registeredDevice.deviceIdentifier,
        deviceName: registeredDevice.deviceName,
      );

      await SessionService.saveSession(session);

      _addLog("Device registered successfully");
      _addLog("Terminal ID: ${session.terminalId}");

      if (!mounted) return;

      _showSnackBar("Device registered successfully");
      widget.onRegistered(session);
    } catch (e) {
      _addLog("Registration error: $e");
      _showSnackBar("Registration failed");
    } finally {
      if (mounted) {
        setState(() {
          isRegistering = false;
        });
      }
    }
  }

  void _addLog(String message) {
    setState(() {
      logs.insert(0, "[${DateTime.now()}] $message");
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildLogs() {
    if (logs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text("No logs yet"),
        ),
      );
    }

    return Column(
      children: logs.map((log) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(log),
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    enterpriseCodeController.dispose();
    deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dropdownValue =
        (selectedRole == "OWNER" || selectedRole == "CASHIER")
            ? selectedRole
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Device Registration"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Register this phone once with enterprise code and role. After registration, this phone will receive QR using its terminal ID.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Register Device",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: enterpriseCodeController,
                      decoration: const InputDecoration(
                        labelText: "Enterprise Code",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: deviceNameController,
                      decoration: const InputDecoration(
                        labelText: "Device Name",
                        border: OutlineInputBorder(),
                        hintText: "Example: Owner Phone / Cashier Phone",
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: dropdownValue,
                      decoration: const InputDecoration(
                        labelText: "Role",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "OWNER",
                          child: Text("OWNER"),
                        ),
                        DropdownMenuItem(
                          value: "CASHIER",
                          child: Text("CASHIER"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          selectedRole = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isRegistering ? null : _registerDevice,
                        child: Text(
                          isRegistering
                              ? "Registering..."
                              : "Validate & Register Device",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Logs",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildLogs(),
          ],
        ),
      ),
    );
  }
}