import 'package:flutter/material.dart';

import '../models/device_login_request.dart';
import '../models/device_registration_response.dart';
import '../models/device_session.dart';
import '../models/enterprise_validation_request.dart';
import '../models/enterprise_validation_response.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

class LoginPage extends StatefulWidget {
  final Function(DeviceSession) onLoginSuccess;
  final VoidCallback onGoToRegistration;

  const LoginPage({
    super.key,
    required this.onLoginSuccess,
    required this.onGoToRegistration,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController enterpriseCodeController =
      TextEditingController();

  bool isLoading = false;
  final List<String> logs = [];

  Future<void> _loginDevice() async {
    final enterpriseCode = enterpriseCodeController.text.trim().toUpperCase();

    if (enterpriseCode.isEmpty) {
      _showSnackBar("Please enter enterprise code");
      return;
    }

    setState(() {
      isLoading = true;
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

      final loginResponse = await ApiService.loginDevice(
        DeviceLoginRequest(
          enterpriseCode: validationResult.enterpriseCode,
          deviceIdentifier: deviceIdentifier,
        ),
      );

      if (loginResponse == null ||
          loginResponse["success"] != true ||
          loginResponse["data"] == null) {
        final msg =
            (loginResponse?["message"] ?? "Device is not registered")
                .toString();

        _addLog(msg);
        _showSnackBar(msg);
        return;
      }

      final loginData = loginResponse["data"] as Map<String, dynamic>;
      final device = DeviceRegistrationResponse.fromJson(loginData);

      final session = DeviceSession(
        enterpriseCode: device.enterpriseCode,
        enterpriseName: device.enterpriseName,
        role: device.role,
        terminalId: device.terminalId,
        deviceIdentifier: device.deviceIdentifier,
        deviceName: device.deviceName,
      );

      await SessionService.saveSession(session);

      _addLog("Login successful");
      _addLog("Terminal ID: ${session.terminalId}");

      if (!mounted) return;

      _showSnackBar("Login successful");
      widget.onLoginSuccess(session);
    } catch (e) {
      _addLog("Login error: $e");
      _showSnackBar("Login failed");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Device Login"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Login with your enterprise code. If this phone is already registered, backend will return the permanent terminal ID.",
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
                        "Login Device",
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _loginDevice,
                        child: Text(isLoading ? "Logging in..." : "Login"),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: isLoading ? null : widget.onGoToRegistration,
                        child: const Text("New Device Registration"),
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