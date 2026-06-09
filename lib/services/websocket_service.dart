// lib/services/websocket_service.dart
//
// Manages the WebSocket connection to /api/v1/navigation/ws/{session_id}.
// Exposes a broadcast Stream<NavigationState> that providers subscribe to.
// Call connect() once after route is established, dispose() on screen exit.

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';
import '../models/navigation_state.dart';

class WebSocketService {
  WebSocketService({required this.sessionId, required this.apiKey});

  final String sessionId;
  final String apiKey;

  WebSocketChannel? _channel;
  final _controller = StreamController<NavigationState>.broadcast();

  /// Broadcast stream of navigation states pushed by the backend.
  Stream<NavigationState> get stateStream => _controller.stream;

  /// Opens the WebSocket connection and starts forwarding messages.
  void connect() {
    final base = Env.apiBase;

    // Convert http(s) scheme to ws(s).
    final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
    final uri = Uri(
      scheme: wsScheme,
      host: base.host,
      port: base.port,
      path: '/api/v1/navigation/ws/$sessionId',
      queryParameters: {'api_key': apiKey},
    );

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (dynamic message) {
        try {
          final json = jsonDecode(message as String) as Map<String, dynamic>;
          final state = NavigationState.fromJson(json);
          if (!_controller.isClosed) _controller.add(state);
        } catch (e) {
          _controller.addError(
            Exception('WebSocket parse error: $e\nRaw: $message'),
          );
        }
      },
      onError: (Object error) {
        if (!_controller.isClosed) _controller.addError(error);
      },
      onDone: () {
        // Server closed the connection (e.g. arrival confirmed).
        if (!_controller.isClosed) _controller.close();
      },
    );
  }

  /// Send an arbitrary JSON payload to the backend over the WS channel.
  /// Currently unused but available for future client→server messages.
  void send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  /// Closes the WebSocket and stream. Must be called when done.
  Future<void> dispose() async {
    await _channel?.sink.close();
    await _controller.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mock WebSocket service — used by IndoorNavigationScreen until backend
// Phase 3 is complete and real WS endpoint is available.
//
// TODO [Backend Phase 3 / Hardware]: Delete this class and use WebSocketService.
// ─────────────────────────────────────────────────────────────────────────────

class MockWebSocketService {
  final _controller = StreamController<NavigationState>.broadcast();
  Timer? _timer;

  Stream<NavigationState> get stateStream => _controller.stream;

  void connect() {
    double score = 0.3;
    double bearing = 45.0;

    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      // Oscillate score to simulate hot/cold movement.
      score = (score + 0.07) % 1.0;
      bearing = (bearing + 5) % 360;

      if (!_controller.isClosed) {
        _controller.add(NavigationState(
          bearing: bearing,
          distanceMetres: 20 - score * 18,
          hotColdScore: score,
          hint: score > 0.6 ? 'Getting warmer 🌡' : 'Getting colder ❄️',
          waypointIndex: 0,
          arrived: false,
        ));
      }
    });
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }
}
