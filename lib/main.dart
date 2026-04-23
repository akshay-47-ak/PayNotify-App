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
      selectedRole = session.role;

      _connectWebSocket(session.terminalId);

      _addLog(
        "Loaded saved session: ${session.enterpriseCode} | "
        "${session.role} | ${session.terminalId}",
      );
    } else {
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
        final amount = (data["amount"] ?? "").toString();

        _addLog(
          "Terminal event | "
          "terminalId=$terminalId | "
          "paymentId=$paymentId | "
          "status=$status | "
          "txnRef=$transactionRef | "
          "amount=$amount | "
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
        _showSnackBar("Enterprise validation failed");
        return;
      }

      final validationData =
          validationResponse["data"] is Map<String, dynamic>
              ? validationResponse["data"] as Map<String, dynamic>
              : <String, dynamic>{};

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

      final deviceIdentifier =
          "${validationResult.enterpriseCode}_${selectedRole}_${DateTime.now().millisecondsSinceEpoch}";

      final registerResponse = await ApiService.registerDevice(
        DeviceRegistrationRequest(
          enterpriseCode: validationResult.enterpriseCode,
          role: selectedRole,
          deviceIdentifier: deviceIdentifier,
          deviceName: deviceName,
        ),
      );

      if (registerResponse == null) {
        _showSnackBar("Device registration failed");
        return;
      }

      final registerData =
          registerResponse["data"] is Map<String, dynamic>
              ? registerResponse["data"] as Map<String, dynamic>
              : <String, dynamic>{};

      final registeredDevice = DeviceRegistrationResponse.fromJson(registerData);

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
              initialValue: selectedRole,
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

  Widget _buildLogsSection() {
    return Expanded(
      child: logs.isEmpty
          ? const Center(
              child: Text("No logs yet"),
            )
          : ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(logs[index]),
                  ),
                );
              },
            ),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "This device registers under an enterprise as OWNER or CASHIER, listens for payment notifications, and communicates with backend using enterprise/device registration and terminal-based WebSocket routing.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildRegistrationCard(),
            const SizedBox(height: 16),
            _buildSessionCard(),
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
            _buildLogsSection(),
          ],
        ),
      ),
    );
  }
}