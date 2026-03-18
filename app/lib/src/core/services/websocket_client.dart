import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

class MessageEnvelope {
  final String type;
  final String id;
  final Map<String, dynamic>? payload;
  final int timestamp;

  MessageEnvelope({
    required this.type,
    this.id = '',
    this.payload,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory MessageEnvelope.fromJson(Map<String, dynamic> json) {
    return MessageEnvelope(
      type: json['type'] as String,
      id: json['id'] as String? ?? '',
      payload: json['payload'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toRadixString(16) : id,
        'payload': payload,
        'timestamp': timestamp,
      };

  String encode() => json.encode(toJson());
}

enum ConnectionStatus { disconnected, connecting, connected, error }

class WebSocketClient {
  final String baseUrl;
  final String token;

  WebSocketChannel? _channel;
  ConnectionStatus _status = ConnectionStatus.disconnected;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 8;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _messageController = StreamController<MessageEnvelope>.broadcast();
  final _binaryController = StreamController<Uint8List>.broadcast();

  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  Stream<MessageEnvelope> get messages => _messageController.stream;
  Stream<Uint8List> get binaryMessages => _binaryController.stream;
  ConnectionStatus get status => _status;

  /// Filter messages by type
  Stream<MessageEnvelope> on(String type) =>
      messages.where((m) => m.type == type);

  WebSocketClient({
    required this.baseUrl,
    required this.token,
  });

  /// Derive WebSocket URL from HTTP base URL
  /// http://x → ws://x/ws, https://x → wss://x/ws
  String get _wsUrl {
    final wsScheme = baseUrl.startsWith('https') ? 'wss' : 'ws';
    final url = baseUrl.replaceFirst(RegExp(r'^https?'), wsScheme);
    final trimmed = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    return '$trimmed/ws?token=$token';
  }

  Future<void> connect() async {
    if (_status == ConnectionStatus.connecting) return;
    _setStatus(ConnectionStatus.connecting);

    try {
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;

      _setStatus(ConnectionStatus.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();

      _channel!.stream.listen(
        (data) {
          if (data is String) {
            try {
              final decoded = json.decode(data) as Map<String, dynamic>;
              _messageController.add(MessageEnvelope.fromJson(decoded));
            } catch (_) {}
          } else if (data is List<int>) {
            _binaryController.add(Uint8List.fromList(data));
          }
        },
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
      );
    } catch (e) {
      _setStatus(ConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  void send(MessageEnvelope message) {
    if (_status != ConnectionStatus.connected) return;
    _channel?.sink.add(message.encode());
  }

  void sendTyped(String type, [Map<String, dynamic>? payload]) {
    send(MessageEnvelope(type: type, payload: payload));
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setStatus(ConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _statusController.close();
    _messageController.close();
    _binaryController.close();
  }

  void _onDisconnected() {
    _heartbeatTimer?.cancel();
    if (_status != ConnectionStatus.disconnected) {
      _setStatus(ConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    final delay = Duration(
      seconds: (1 << _reconnectAttempts).clamp(1, _maxReconnectDelay),
    );
    _reconnectAttempts++;
    _reconnectTimer = Timer(delay, connect);
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_status == ConnectionStatus.connected) {
        try {
          _channel?.sink.add('{"type":"ping"}');
        } catch (_) {
          _onDisconnected();
        }
      }
    });
  }

  void _setStatus(ConnectionStatus s) {
    _status = s;
    _statusController.add(s);
  }
}
