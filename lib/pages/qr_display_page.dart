import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/device_session.dart';
import '../models/payment_notification.dart';
import '../services/notification_handler.dart';
import '../services/session_service.dart';
import '../services/websocket_service.dart';

class QrDisplayPage extends StatefulWidget {
  final DeviceSession session;
  final VoidCallback onClearSession;

  const QrDisplayPage({
    super.key,
    required this.session,
    required this.onClearSession,
  });

  @override
  State<QrDisplayPage> createState() => _QrDisplayPageState();
}

class _QrDisplayPageState extends State<QrDisplayPage> {
  static const MethodChannel _channel =
      MethodChannel('payment_notification_channel');

  final List<String> logs = [];

  String currentQrBase64 = "";
  String currentQrPaymentId = "";
  String currentQrTransactionRef = "";
  String currentQrStatus = "";

  @override
  void initState() {
    super.initState();
    _setupNotificationChannel();
    _connectWebSocket();

    _addLog(
      "Loaded device: ${widget.session.enterpriseCode} | "
      "${widget.session.role} | ${widget.session.terminalId}",
    );
  }

  void _connectWebSocket() {
    WebSocketService.connect(
      terminalId: widget.session.terminalId,
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
          "Terminal event | paymentId=$paymentId | "
          "status=$status | txnRef=$transactionRef | message=$message",
        );
      },
      onConnectionLog: (message) {
        _addLog(message);
      },
    );
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
            widget.session,
          );

          _addLog(
            "Notification processed | "
            "sent=${result["sent"]} | "
            "status=${result["status"]} | "
            "txnRef=${result["transactionRef"] ?? ""} | "
            "paymentId=${result["paymentId"] ?? ""} | "
            "message=${result["message"] ?? ""}",
          );
        } catch (e) {
          _addLog("Notification handling error: $e");
        }
      }
    });
  }

  Future<void> _openNotificationAccessSettings() async {
    try {
      await _channel.invokeMethod("openNotificationAccessSettings");
      _addLog("Opened notification access settings");
    } catch (e) {
      _addLog("Failed to open settings: $e");
    }
  }

  Future<void> _logout() async {
    await SessionService.clearSession();
    WebSocketService.disconnect();

    if (!mounted) return;

    widget.onClearSession();
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      logs.insert(0, "[${DateTime.now()}] $message");
    });
  }

  Widget _buildDeviceCard() {
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
                  "Logged In Device",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow("Enterprise", widget.session.enterpriseCode),
            _buildInfoRow("Enterprise Name", widget.session.enterpriseName),
            _buildInfoRow("Role", widget.session.role),
            _buildInfoRow("Terminal ID", widget.session.terminalId),
            _buildInfoRow("Device Name", widget.session.deviceName),
            _buildInfoRow("Device ID", widget.session.deviceIdentifier),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openNotificationAccessSettings,
              child: const Text("Enable Notification Access"),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _logout,
              child: const Text("Logout"),
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
                  "QR Payment",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                      width: 230,
                      height: 230,
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text("Waiting for QR from web..."),
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
          Expanded(child: Text(value.isEmpty ? "-" : value)),
        ],
      ),
    );
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
    WebSocketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showDeviceCard = currentQrBase64.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("QR Payment Page"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDeviceCard) _buildDeviceCard(),
            if (showDeviceCard) const SizedBox(height: 16),
            _buildQrCard(),
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