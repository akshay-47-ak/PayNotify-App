import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/device_session.dart';
import '../models/payment_notification.dart';
import '../services/api_service.dart';
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
  static const Duration _manualConfirmFallbackWindow = Duration(minutes: 3);

  final List<String> logs = [];

  String currentQrBase64 = "";
  String currentQrPaymentId = "";
  String currentQrTransactionRef = "";
  String currentQrStatus = "";
  DateTime? currentQrGeneratedAt;
  bool isManualConfirming = false;
  Timer? _manualConfirmRefreshTimer;

  Uint8List _decodeQrImage(String value) {
    final commaIndex = value.indexOf(",");
    final base64Value = value.startsWith("data:image/") && commaIndex >= 0
        ? value.substring(commaIndex + 1)
        : value;

    return base64Decode(base64Value);
  }

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
      token: widget.session.token,
      onTerminalEvent: (data) {
        final status = (data["status"] ?? "").toString();
        final paymentId = (data["paymentId"] ?? "").toString();
        final transactionRef = (data["transactionRef"] ?? "").toString();
        final message = (data["message"] ?? "").toString();
        final qrImageBase64 = (data["qrImageBase64"] ?? "").toString();
        final eventType = (data["eventType"] ?? "").toString();
        final eventTimestamp = _parseEventTimestamp(data["timestamp"]);
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
            currentQrGeneratedAt = eventTimestamp ?? DateTime.now();
            _startManualConfirmRefreshTimer();
          } else if (paymentId.isNotEmpty &&
              paymentId == currentQrPaymentId &&
              status.isNotEmpty &&
              shouldUpdateStatus) {
            currentQrStatus = status;
            if (_isCancelledStatus(status)) {
              _clearCurrentQrDisplay();
            }
            if (!_isWaitingStatus(status)) {
              _stopManualConfirmRefreshTimer();
            }
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

  Future<void> _manualConfirmPayment() async {
    if (currentQrPaymentId.isEmpty || isManualConfirming) {
      return;
    }

    final form = await _showManualConfirmDialog();
    if (form == null) {
      return;
    }

    if (!mounted) return;

    setState(() {
      isManualConfirming = true;
    });

    try {
      final response = await ApiService.manuallyConfirmPayment(
        paymentId: currentQrPaymentId,
        utr: form["utr"],
        payerName: form["payerName"],
        reason: form["reason"],
      );

      if (response == null ||
          response["success"] != true ||
          response["data"] == null) {
        final message = (response?["message"] ?? "Manual confirmation failed")
            .toString();
        _addLog("Manual confirmation failed: $message");
        _showSnackBar(message);
        return;
      }

      final data = response["data"] as Map<String, dynamic>;
      final status = (data["status"] ?? "").toString();
      final paymentId = (data["paymentId"] ?? currentQrPaymentId).toString();
      final transactionRef = (data["transactionRef"] ?? currentQrTransactionRef)
          .toString();
      final message = (data["message"] ?? response["message"] ?? "").toString();

      if (!mounted) return;

      setState(() {
        if (paymentId.isNotEmpty) {
          currentQrPaymentId = paymentId;
        }
        if (transactionRef.isNotEmpty) {
          currentQrTransactionRef = transactionRef;
        }
        if (status.isNotEmpty) {
          currentQrStatus = status;
        }
      });

      _addLog(
        "Manual confirmation completed | paymentId=$paymentId | "
        "status=$status | message=$message",
      );
      _showSnackBar(message.isEmpty ? "Payment manually confirmed" : message);
    } catch (e) {
      _addLog("Manual confirmation error: $e");
      _showSnackBar("Manual confirmation failed");
    } finally {
      if (mounted) {
        setState(() {
          isManualConfirming = false;
        });
      }
    }
  }

  Future<Map<String, String?>?> _showManualConfirmDialog() {
    final utrController = TextEditingController();
    final payerNameController = TextEditingController();
    final reasonController = TextEditingController(
      text: "Manual fallback confirmation from Android terminal",
    );

    return showDialog<Map<String, String?>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Manual Confirmation"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: utrController,
                  decoration: const InputDecoration(
                    labelText: "UTR / Reference",
                    hintText: "Optional",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: payerNameController,
                  decoration: const InputDecoration(
                    labelText: "Payer Name",
                    hintText: "Optional",
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Reason",
                    hintText: "Optional",
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                String? optionalText(TextEditingController controller) {
                  final value = controller.text.trim();
                  return value.isEmpty ? null : value;
                }

                Navigator.of(context).pop({
                  "utr": optionalText(utrController),
                  "payerName": optionalText(payerNameController),
                  "reason": optionalText(reasonController),
                });
              },
              child: const Text("Confirm"),
            ),
          ],
        );
      },
    ).whenComplete(() {
      utrController.dispose();
      payerNameController.dispose();
      reasonController.dispose();
    });
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

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _shouldApplyTerminalStatus({
    required String status,
    String eventType = "",
  }) {
    return !_isPhonePeConfirmationRequired(
      status: status,
      eventType: eventType,
    );
  }

  bool get _canManualConfirmCurrentPayment {
    return currentQrPaymentId.isNotEmpty &&
        _isWaitingStatus(currentQrStatus) &&
        _isManualConfirmWindowOpen;
  }

  bool get _isManualConfirmWindowOpen {
    final generatedAt = currentQrGeneratedAt;
    if (generatedAt == null) {
      return false;
    }

    return DateTime.now().difference(generatedAt) >=
        _manualConfirmFallbackWindow;
  }

  bool _isWaitingStatus(String status) {
    return status == "WAITING" || status == "PENDING";
  }

  bool _isCancelledStatus(String status) {
    return status == "CANCELLED_BY_CASHIER";
  }

  bool _isPhonePeConfirmationRequired({
    required String status,
    String eventType = "",
  }) {
    return eventType == _phonePeConfirmationEvent ||
        status == _phonePeWaitingConfirmationStatus;
  }

  void _clearCurrentQrDisplay() {
    currentQrBase64 = "";
    currentQrGeneratedAt = null;
    _stopManualConfirmRefreshTimer();
  }

  DateTime? _parseEventTimestamp(dynamic value) {
    if (value == null) {
      return null;
    }

    final timestamp = value is int ? value : int.tryParse(value.toString());
    if (timestamp == null || timestamp <= 0) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  void _startManualConfirmRefreshTimer() {
    _manualConfirmRefreshTimer?.cancel();
    _manualConfirmRefreshTimer = Timer.periodic(const Duration(seconds: 5), (
      _,
    ) {
      if (!mounted || !_isWaitingStatus(currentQrStatus)) {
        _stopManualConfirmRefreshTimer();
        return;
      }

      setState(() {});
    });
  }

  void _stopManualConfirmRefreshTimer() {
    _manualConfirmRefreshTimer?.cancel();
    _manualConfirmRefreshTimer = null;
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
                      _decodeQrImage(currentQrBase64),
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
                  if (_canManualConfirmCurrentPayment) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: isManualConfirming
                          ? null
                          : _manualConfirmPayment,
                      icon: isManualConfirming
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified),
                      label: const Text("Manual Confirm"),
                    ),
                  ],
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
    _stopManualConfirmRefreshTimer();
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
