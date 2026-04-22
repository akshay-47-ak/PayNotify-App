import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class WebSocketService {
  static const String wsUrl = "http://172.16.2.170:8080/ws";

  static StompClient? _client;

  static void connect({
    required String terminalId,
    required Function(Map<String, dynamic>) onTerminalEvent,
    required Function(String) onConnectionLog,
  }) {
    disconnect();

    _client = StompClient(
      config: StompConfig.sockJS(
        url: wsUrl,
        onConnect: (frame) {
          onConnectionLog("WebSocket connected");

          _client?.subscribe(
            destination: "/topic/terminal/$terminalId",
            callback: (frame) {
              try {
                final body = frame.body;
                if (body == null || body.trim().isEmpty) {
                  return;
                }

                final data = jsonDecode(body) as Map<String, dynamic>;
                onTerminalEvent(data);
              } catch (e) {
                onConnectionLog("WebSocket message parse error: $e");
              }
            },
          );
        },
        onWebSocketError: (dynamic error) {
          onConnectionLog("WebSocket error: $error");
        },
        onStompError: (frame) {
          onConnectionLog("STOMP error: ${frame.body}");
        },
        onDisconnect: (frame) {
          onConnectionLog("WebSocket disconnected");
        },
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );

    _client?.activate();
  }

  static void disconnect() {
    _client?.deactivate();
    _client = null;
  }
}