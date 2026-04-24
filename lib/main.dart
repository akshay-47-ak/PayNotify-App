import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/device_registration_request.dart';
import 'models/device_registration_response.dart';
import 'models/device_session.dart';
import 'models/enterprise_validation_request.dart';
import 'models/enterprise_validation_response.dart';
import 'models/payment_notification.dart';
import 'services/api_service.dart';
import 'services/notification_handler.dart';
import 'services/session_service.dart';
import 'services/websocket_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pay Alert Bridge',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _channel =
      MethodChannel('payment_notification_channel');

  final TextEditingController enterpriseCodeController =
      TextEditingController();
  final TextEditingController deviceNameController = TextEditingController();

  final List<String> logs = [];

  String selectedRole = "OWNER";
  bool isLoading = true;
  bool isRegistering = false;

  DeviceSession? currentSession;

  String currentQrBase64 = "";
  String currentQrPaymentId = "";
  String currentQrTransactionRef = "";
  String currentQrStatus = "";

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _setupNotificationChannel();
  }

  Future<void> _initializeApp() async {
    final session = await SessionService.getSession();

    if (!mounted) return;

    setState(() {
      currentSession = session;
      isLoading = false;
    });

    if (session != null) {
      enterpriseCodeController.text = session.enterpriseCode;
      deviceNameController.text = session.deviceName;
      selectedRole =
          (session.role == "OWNER" || session.role == "CASHIER")
              ? session.role
              : "OWNER";

      _connectWebSocket(session.terminalId);

      _addLog(
        "Loaded saved session: ${session.enterpriseCode} | "
        "${session.role} | ${session.terminalId}",
      );
    } else {
      selectedRole = "OWNER";
      _addLog("No saved device session found");
    }
  }

  void _setupNotificationChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == "onNotificationReceived") {
        try {
          final data = Map<dynamic, dynamic>.from(call.arguments);
          final notification = PaymentNotification.fromMap(data);

          _addLog(
            "Notification captured: ${notification.packageName} | ${notification.title}",
          );

          final result = await NotificationHandler.processNotification(
            notification,
            currentSession,
          );

          if (!mounted) return;

          _addLog(
            "Notification processed | "
            "sent=${result["sent"]} | "
            "status=${result["status"]} | "
            "txnRef=${result["transactionRef"] ?? ""} | "
            "paymentId=${result["paymentId"] ?? ""}",
          );
        } catch (e) {
          _addLog("Notification handling error: $e");
        }
      }
    });
  }

  void _connectWebSocket(String terminalId) {
    WebSocketService.connect(
      terminalId: terminalId,
      onTerminalEvent: (data) {
        final status = (data["status"] ?? "").toString();
        final paymentId = (data["paymentId"] ?? "").toString();
        final transactionRef = (data["transactionRef"] ?? "").toString();
        final message = (data["message"] ?? "").toString();
        final qrImageBase64 = (data["qrImageBase64"] ?? "").toString();

        if (!mounted) return;

        setState(() {
          if (qrImageBase64.isNotEmpty) {
            currentQrBase64 = qrImageBase64;
            currentQrPaymentId = paymentId;
            currentQrTransactionRef = transactionRef;
            currentQrStatus = status;
          } else if (paymentId.isNotEmpty &&
              paymentId == currentQrPaymentId &&
              status.isNotEmpty) {
            currentQrStatus = status;
          }
        });

        _addLog(
          "Terminal event | "
          "terminalId=$terminalId | "
          "paymentId=$paymentId | "
          "status=$status | "
          "txnRef=$transactionRef | "
          "message=$message",
        );
      },
      onConnectionLog: (message) {
        _addLog(message);
      },
    );
  }

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
        EnterpriseValidationRequest(
          enterpriseCode: enterpriseCode,
        ),
      );

      if (validationResponse == null) {
        _addLog("Enterprise validation failed: null response");
        _showSnackBar("Enterprise validation failed");
        return;
      }

      final validationSuccess = validationResponse["success"] == true;
      final validationMessage =
          (validationResponse["message"] ?? "").toString();

      if (!validationSuccess) {
        _addLog(
          "Enterprise validation failed: ${validationMessage.isEmpty ? 'Unknown error' : validationMessage}",
        );
        _showSnackBar(
          validationMessage.isEmpty
              ? "Enterprise validation failed"
              : validationMessage,
        );
        return;
      }

      final validationData =
          validationResponse["data"] is Map<String, dynamic>
              ? validationResponse["data"] as Map<String, dynamic>
              : <String, dynamic>{};

      if (validationData.isEmpty) {
        _addLog("Enterprise validation failed: empty data");
        _showSnackBar("Enterprise validation failed");
        return;
      }

      final validationResult =
          EnterpriseValidationResponse.fromJson(validationData);

      if (!validationResult.valid) {
        _showSnackBar(validationResult.message);
        _addLog(
          "Enterprise validation failed | "
          "status=${validationResult.status} | "
          "message=${validationResult.message}",
        );
        return;
      }

      _addLog(
        "Enterprise validated | "
        "${validationResult.enterpriseCode} | "
        "${validationResult.enterpriseName}",
      );

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

      if (registerResponse == null) {
        _addLog("Device registration failed: null response");
        _showSnackBar("Device registration failed");
        return;
      }

      final registerSuccess = registerResponse["success"] == true;
      final registerMessage = (registerResponse["message"] ?? "").toString();

      if (!registerSuccess) {
        _addLog(
          "Device registration failed: ${registerMessage.isEmpty ? 'Unknown error' : registerMessage}",
        );
        _showSnackBar(
          registerMessage.isEmpty
              ? "Device registration failed"
              : registerMessage,
        );
        return;
      }

      final registerData =
          registerResponse["data"] is Map<String, dynamic>
              ? registerResponse["data"] as Map<String, dynamic>
              : <String, dynamic>{};

      if (registerData.isEmpty) {
        _addLog("Device registration failed: empty data");
        _showSnackBar("Device registration failed");
        return;
      }

      final registeredDevice = DeviceRegistrationResponse.fromJson(registerData);

      if (registeredDevice.terminalId.trim().isEmpty ||
          registeredDevice.enterpriseCode.trim().isEmpty ||
          registeredDevice.deviceIdentifier.trim().isEmpty) {
        _addLog("Device registration failed: invalid response data");
        _showSnackBar("Device registration failed");
        return;
      }

      final session = DeviceSession(
        enterpriseCode: registeredDevice.enterpriseCode,
        enterpriseName: registeredDevice.enterpriseName,
        role: registeredDevice.role,
        terminalId: registeredDevice.terminalId,
        deviceIdentifier: registeredDevice.deviceIdentifier,
        deviceName: registeredDevice.deviceName,
      );

      await SessionService.saveSession(session);

      WebSocketService.disconnect();
      _connectWebSocket(session.terminalId);

      if (!mounted) return;

      setState(() {
        currentSession = session;
      });

      _addLog(
        "Device registered successfully | "
        "role=${session.role} | "
        "terminalId=${session.terminalId} | "
        "deviceIdentifier=${session.deviceIdentifier}",
      );

      _showSnackBar("Device registered successfully");
    } catch (e) {
      _addLog("Registration error: $e");
      _showSnackBar("Registration failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          isRegistering = false;
        });
      }
    }
  }

  Future<void> _clearSession() async {
    await SessionService.clearSession();
    WebSocketService.disconnect();

    if (!mounted) return;

    setState(() {
      currentSession = null;
      selectedRole = "OWNER";
      enterpriseCodeController.clear();
      deviceNameController.clear();
      currentQrBase64 = "";
      currentQrPaymentId = "";
      currentQrTransactionRef = "";
      currentQrStatus = "";
    });

    _addLog("Local device session cleared");
    _showSnackBar("Session cleared");
  }

  Future<void> _openNotificationAccessSettings() async {
    try {
      await _channel.invokeMethod("openNotificationAccessSettings");
      _addLog("Opened notification access settings");
    } catch (e) {
      _addLog("Failed to open settings: $e");
      _showSnackBar("Failed to open notification settings");
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

  Widget _buildRegistrationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Device Registration",
                style: TextStyle(
                  fontSize: 18,
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
                hintText: "Enter enterprise code",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: deviceNameController,
              decoration: const InputDecoration(
                labelText: "Device Name",
                border: OutlineInputBorder(),
                hintText: "Example: Owner Phone / Cashier Phone 1",
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: (selectedRole == "OWNER" || selectedRole == "CASHIER")
                  ? selectedRole
                  : null,
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
                  isRegistering ? "Registering..." : "Validate & Register Device",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard() {
    if (currentSession == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Device is not registered yet. Register this phone with enterprise code and role first.",
                ),
              ),
            ],
          ),
        ),
      );
    }

    final session = currentSession!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: const [
                Icon(Icons.phone_android),
                SizedBox(width: 10),
                Text(
                  "Registered Device",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow("Enterprise", session.enterpriseCode),
            _buildInfoRow("Enterprise Name", session.enterpriseName),
            _buildInfoRow("Role", session.role),
            _buildInfoRow("Terminal ID", session.terminalId),
            _buildInfoRow("Device Name", session.deviceName),
            _buildInfoRow("Device Identifier", session.deviceIdentifier),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _openNotificationAccessSettings,
                    child: const Text("Enable Notification Access"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearSession,
                    child: const Text("Clear Session"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: const [
                Icon(Icons.qr_code),
                SizedBox(width: 10),
                Text(
                  "QR Display",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (currentQrBase64.isNotEmpty)
                    Image.memory(
                      base64Decode(currentQrBase64),
                      width: 220,
                      height: 220,
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text("No QR received yet"),
                    ),
                  const SizedBox(height: 16),
                  _buildInfoRow("Payment ID", currentQrPaymentId),
                  _buildInfoRow("Transaction Ref", currentQrTransactionRef),
                  _buildInfoRow("Status", currentQrStatus),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? "-" : value),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
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
    WebSocketService.disconnect();
    enterpriseCodeController.dispose();
    deviceNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Alert Bridge"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "This device registers under an enterprise as OWNER or CASHIER, receives QR over terminal-based WebSocket routing, listens for payment notifications, and sends notification data to backend.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              _buildRegistrationCard(),
              const SizedBox(height: 16),
              _buildSessionCard(),
              const SizedBox(height: 16),
              _buildQrCard(),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Logs",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _buildLogsList(),
            ],
          ),
        ),
      ),
    );
  }
}