import 'package:flutter/material.dart';

import '../models/device_login_request.dart';
import '../models/device_registration_response.dart';
import '../models/device_session.dart';
import '../models/enterprise_validation_request.dart';
import '../models/enterprise_validation_response.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../ui/app_theme.dart';
import '../widgets/app_logo.dart';

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

      final validationData = validationResponse["data"] as Map<String, dynamic>;

      final validationResult = EnterpriseValidationResponse.fromJson(
        validationData,
      );

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
        final msg = (loginResponse?["message"] ?? "Device is not registered")
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildLogs() {
    if (logs.isEmpty) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(16), child: Text("No logs yet")),
      );
    }

    return Column(
      children: logs.map((log) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(log)),
              ],
            ),
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
      appBar: AppBar(title: const Text("Device Login")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppLayout.pagePadding(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.maxContentWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 72)),
                  const SizedBox(height: 20),
                  Text(
                    "Login to PayNotify",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter your enterprise code to load the registered terminal for this device.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Login Device",
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: enterpriseCodeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: "Enterprise Code",
                              hintText: "Example: AB1234",
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: isLoading ? null : _loginDevice,
                            icon: isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(isLoading ? "Logging in..." : "Login"),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: isLoading
                                ? null
                                : widget.onGoToRegistration,
                            icon: const Icon(Icons.app_registration),
                            label: const Text("New Device Registration"),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Logs",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLogs(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
