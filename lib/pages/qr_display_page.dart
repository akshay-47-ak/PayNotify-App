import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/device_session.dart';
import '../models/payment_notification.dart';
import '../services/notification_handler.dart';
import '../services/session_service.dart';
import '../services/websocket_service.dart';
import '../ui/app_theme.dart';

class QrDisplayPage extends StatefulWidget {
  final DeviceSession session;
  final VoidCallback onClearSession;
  final VoidCallback onGoToMain;
  final VoidCallback onOpenProfile;

  const QrDisplayPage({
    super.key,
    required this.session,
    required this.onClearSession,
    required this.onGoToMain,
    required this.onOpenProfile,
  });

  @override
  State<QrDisplayPage> createState() => _QrDisplayPageState();
}

class _QrDisplayPageState extends State<QrDisplayPage> {
  static const MethodChannel _channel = MethodChannel(
    'payment_notification_channel',
  );
  static const String _phonePeConfirmationEvent =
      "PHONEPE_PAYMENT_CONFIRMATION_REQUIRED";
  static const String _phonePeWaitingConfirmationStatus =
      "PHONEPE_MATCHED_WAITING_CONFIRMATION";

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
        final eventType = (data["eventType"] ?? "").toString();
        final shouldUpdateStatus = _shouldApplyTerminalStatus(
          status: status,
          eventType: eventType,
        );

        if (!mounted) return;

        setState(() {
          if (qrImageBase64.isNotEmpty) {
            currentQrBase64 = qrImageBase64;
            currentQrPaymentId = paymentId;
            currentQrTransactionRef = transactionRef;
            currentQrStatus = status;
          } else if (paymentId.isNotEmpty &&
              paymentId == currentQrPaymentId &&
              status.isNotEmpty &&
              shouldUpdateStatus) {
            currentQrStatus = status;
          }
        });

        if (!shouldUpdateStatus) {
          _addLog(
            "PhonePe confirmation is pending on cashier web; Android is waiting for final status.",
          );
        }

        _addLog(
          "Terminal event | paymentId=$paymentId | "
          "status=$status | eventType=$eventType | "
          "txnRef=$transactionRef | message=$message",
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
          final resultPaymentId = (result["paymentId"] ?? "").toString();
          final resultStatus = (result["status"] ?? "").toString();
          final shouldUpdateStatus = _shouldApplyTerminalStatus(
            status: resultStatus,
          );

          if (mounted &&
              resultPaymentId.isNotEmpty &&
              resultPaymentId == currentQrPaymentId &&
              resultStatus.isNotEmpty &&
              shouldUpdateStatus) {
            setState(() {
              currentQrStatus = resultStatus;
            });
          }

          if (!shouldUpdateStatus) {
            _addLog(
              "PhonePe matched. Confirm or reject from the cashier web screen.",
            );
          }

          _addLog(
            "Notification processed | "
            "sent=${result["sent"]} | "
            "status=${result["status"]} | "
            "txnRef=${result["transactionRef"] ?? ""} | "
            "paymentId=${result["paymentId"] ?? ""} | "
            "notificationId=${result["notificationId"] ?? ""} | "
            "utr=${result["utr"] ?? ""} | "
            "amountMatched=${result["amountMatched"] ?? ""} | "
            "expectedAmount=${result["expectedAmount"] ?? ""} | "
            "receivedAmount=${result["receivedAmount"] ?? ""} | "
            "payerName=${result["payerName"] ?? ""} | "
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

  void _openNotificationLog() {
    Navigator.of(context).pushNamed(
      "/notification-log",
      arguments: List<String>.unmodifiable(logs),
    );
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() {
      logs.insert(0, "[${DateTime.now()}] $message");
    });
  }

  bool _shouldApplyTerminalStatus({
    required String status,
    String eventType = "",
  }) {
    return eventType != _phonePeConfirmationEvent &&
        status != _phonePeWaitingConfirmationStatus;
  }

  Widget _buildDeviceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.phone_android,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  "Logged In Device",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
            ElevatedButton.icon(
              onPressed: _openNotificationAccessSettings,
              icon: const Icon(Icons.notifications_active),
              label: const Text("Enable Notification Access"),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.qr_code,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  "QR Payment",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
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
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? "-" : value,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
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
        actions: [
          IconButton(
            tooltip: "Profile",
            onPressed: widget.onOpenProfile,
            icon: const Icon(Icons.account_circle),
          ),
          IconButton(
            tooltip: "Notification Log",
            onPressed: _openNotificationLog,
            icon: const Icon(Icons.receipt_long),
          ),
          IconButton(
            tooltip: "Back to Main",
            onPressed: widget.onGoToMain,
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
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
                  if (showDeviceCard) _buildDeviceCard(),
                  if (showDeviceCard) const SizedBox(height: 16),
                  _buildQrCard(),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _openNotificationLog,
                    icon: const Icon(Icons.receipt_long),
                    label: const Text("View Notification Log"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
