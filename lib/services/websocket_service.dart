import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class WebSocketService {
  static const String wsUrl = "https://briskly-jawline-grief.ngrok-free.dev/ws";

  static StompClient? _client;

  static void connect({
    required String terminalId,
    required String token,
    required Function(Map<String, dynamic>) onTerminalEvent,
    required Function(String) onConnectionLog,
  }) {
    disconnect();

    final authToken = token.trim();
    if (authToken.isEmpty) {
      onConnectionLog(
        "WebSocket skipped: missing JWT token. Please login again.",
      );
      return;
    }

    final uri = Uri.parse(wsUrl).replace(queryParameters: {"token": authToken});

    _client = StompClient(
      config: StompConfig.sockJS(
        url: uri.toString(),
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
