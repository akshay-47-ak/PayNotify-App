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
  final VoidCallback onGoToLogin;

  const RegistrationPage({
    super.key,
    required this.onRegistered,
    required this.onGoToLogin,
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
    final enterpriseCode = enterpriseCodeController.text.trim().toUpperCase();
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

      final deviceIdentifier =
          await SessionService.buildEnterpriseDeviceIdentifier(
        validationResult.enterpriseCode,
      );

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

      if (registeredDevice.status == "ALREADY_REGISTERED") {
        _addLog("Device already registered. Existing terminal ID loaded.");
        _showSnackBar("Device already registered. Logged in.");
      } else {
        _addLog("Device registered successfully");
        _showSnackBar("Device registered successfully");
      }

      _addLog("Terminal ID: ${session.terminalId}");

      if (!mounted) return;

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
    if (!mounted) return;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: isRegistering ? null : widget.onGoToLogin,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Register this phone only once. Backend will generate one permanent terminal ID for this device.",
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
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: "Enterprise Code",
                        border: OutlineInputBorder(),
                        hintText: "Example: AB1234",
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
                      initialValue: dropdownValue,
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
                      onChanged: isRegistering
                          ? null
                          : (value) {
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
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: isRegistering ? null : widget.onGoToLogin,
                        child: const Text("Already Registered? Login"),
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