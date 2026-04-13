import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/payment_notification.dart';
import 'services/notification_handler.dart';

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

    final sent = await NotificationHandler.processNotification(notification);

    setState(() {
      logs.insert(
        0,
        "[${DateTime.now()}] ${notification.packageName} | ${notification.title} | sent=$sent | ${notification.text}",
      );
    });
  }
});

  }

  Future<void> _openNotificationAccessSettings() async {
    try {
      await _channel.invokeMethod("openNotificationAccessSettings");
    } catch (e) {
      setState(() {
        logs.insert(0, "Failed to open settings: $e");
      });
    }
  }

  void _setPaymentId() {
    final paymentId = paymentIdController.text.trim();
    NotificationHandler.setCurrentPaymentId(paymentId);

    setState(() {
      logs.insert(0, "Current Payment ID set: $paymentId");
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment ID set successfully")),
    );
  }

  @override
  void dispose() {
    paymentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Alert Bridge"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Enter payment ID, enable notification access, then payment notifications will be captured and sent to backend.",
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: paymentIdController,
              decoration: const InputDecoration(
                labelText: "Payment ID",
                border: OutlineInputBorder(),
                hintText: "Enter payment ID from QR generation API",
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _setPaymentId,
              child: const Text("Set Payment ID"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openNotificationAccessSettings,
              child: const Text("Enable Notification Access"),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Logs",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: logs.isEmpty
                  ? const Center(child: Text("No notifications captured yet"))
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