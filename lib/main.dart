import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/payment_notification.dart';
import 'services/notification_handler.dart';
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

  final TextEditingController paymentIdController = TextEditingController();
  final List<String> logs = [];

  @override
  void initState() {
    super.initState();

    _connectWebSocket();

    _channel.setMethodCallHandler((call) async {
      if (call.method == "onNotificationReceived") {
        print("Raw native notification data: ${call.arguments}");

        final data = Map<dynamic, dynamic>.from(call.arguments);
        final notification = PaymentNotification.fromMap(data);

        print("packageName = ${notification.packageName}");
        print("title = ${notification.title}");
        print("text = ${notification.text}");
        print("subText = ${notification.subText}");
        print("bigText = ${notification.bigText}");

        final result =
            await NotificationHandler.processNotification(notification);

        if (!mounted) return;

        setState(() {
          logs.insert(
            0,
            "[${DateTime.now()}] "
            "activePaymentId=${NotificationHandler.currentPaymentId} | "
            "txnRef=${result["transactionRef"] ?? ""} | "
            "${notification.packageName} | "
            "${notification.title} | "
            "sent=${result["sent"]} | "
            "status=${result["status"]} | "
            "${result["message"] ?? notification.text}",
          );
        });
      }
    });
  }

  void _connectWebSocket() {
    WebSocketService.connect(
      onActivePaymentReceived: (data) {
        final paymentId = (data["paymentId"] ?? "").toString().trim();

        if (paymentId.isEmpty) {
          return;
        }

        NotificationHandler.setCurrentPaymentId(paymentId);

        if (!mounted) return;

        setState(() {
          paymentIdController.text = paymentId;
          logs.insert(
            0,
            "[${DateTime.now()}] Active Payment ID received from WebSocket: $paymentId",
          );
        });
      },
      onConnectionLog: (message) {
        if (!mounted) return;

        setState(() {
          logs.insert(0, "[${DateTime.now()}] $message");
        });
      },
    );
  }

  Future<void> _openNotificationAccessSettings() async {
    try {
      await _channel.invokeMethod("openNotificationAccessSettings");
    } catch (e) {
      if (!mounted) return;

      setState(() {
        logs.insert(0, "Failed to open settings: $e");
      });
    }
  }

  void _setPaymentId() {
    final paymentId = paymentIdController.text.trim();
    NotificationHandler.setCurrentPaymentId(paymentId);

    setState(() {
      logs.insert(
        0,
        "Active Payment ID set manually for display/debug: $paymentId",
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Active Payment ID updated")),
    );
  }

  @override
  void dispose() {
    WebSocketService.disconnect();
    paymentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activePaymentId = NotificationHandler.currentPaymentId;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Alert Bridge"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "This app listens for UPI/payment notifications, extracts transaction reference from notification text, and sends it to backend. Active Payment ID from WebSocket is shown only for monitoring/debug.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paymentIdController,
              decoration: const InputDecoration(
                labelText: "Active Payment ID (optional / debug)",
                border: OutlineInputBorder(),
                hintText: "Auto-synced from backend WebSocket or enter manually",
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _setPaymentId,
                    child: const Text("Set Active Payment ID"),
                  ),
                ),
              ],
            ),
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
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.sync),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        activePaymentId.isEmpty
                            ? "No active Payment ID received yet"
                            : "Active Payment ID: $activePaymentId",
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
            Expanded(
              child: logs.isEmpty
                  ? const Center(
                      child: Text("No notifications captured yet"),
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
            ),
          ],
        ),
      ),
    );
  }
}