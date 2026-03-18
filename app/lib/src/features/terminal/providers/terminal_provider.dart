import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../../core/providers/connection_provider.dart';
import '../../../core/services/websocket_client.dart';

class TerminalSession {
  final String sessionId;
  final Terminal terminal;

  TerminalSession({required this.sessionId, required this.terminal});
}

class TerminalNotifier extends StateNotifier<List<TerminalSession>> {
  final WebSocketClient? _ws;
  StreamSubscription? _outputSub;
  StreamSubscription? _createdSub;
  Completer<String>? _createCompleter;

  TerminalNotifier(this._ws) : super([]) {
    _listenForOutput();
  }

  void _listenForOutput() {
    if (_ws == null) return;

    _outputSub = _ws.on('terminalOutput').listen((msg) {
      final sessionId = msg.payload?['sessionId'] as String?;
      final data = msg.payload?['data'] as String?;
      if (sessionId == null || data == null) return;

      final session = state.where((s) => s.sessionId == sessionId).firstOrNull;
      session?.terminal.write(data);
    });

    _createdSub = _ws.on('terminalCreated').listen((msg) {
      final sessionId = msg.payload?['sessionId'] as String?;
      if (sessionId != null) {
        _createCompleter?.complete(sessionId);
      }
    });
  }

  Future<TerminalSession> createSession() async {
    _createCompleter = Completer<String>();
    _ws?.sendTyped('terminalCreate');

    final sessionId = await _createCompleter!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => 'fallback-${DateTime.now().millisecondsSinceEpoch}',
    );

    final terminal = Terminal(maxLines: 10000);

    // Wire terminal input → WebSocket
    terminal.onOutput = (data) {
      _ws?.sendTyped('terminalInput', {
        'sessionId': sessionId,
        'data': data,
      });
    };

    final session = TerminalSession(sessionId: sessionId, terminal: terminal);
    state = [...state, session];
    return session;
  }

  void closeSession(String sessionId) {
    _ws?.sendTyped('terminalClose', {'sessionId': sessionId});
    state = state.where((s) => s.sessionId != sessionId).toList();
  }

  void sendInput(String sessionId, String data) {
    _ws?.sendTyped('terminalInput', {
      'sessionId': sessionId,
      'data': data,
    });
  }

  @override
  void dispose() {
    _outputSub?.cancel();
    _createdSub?.cancel();
    for (final session in state) {
      _ws?.sendTyped('terminalClose', {'sessionId': session.sessionId});
    }
    super.dispose();
  }
}

final terminalProvider =
    StateNotifierProvider<TerminalNotifier, List<TerminalSession>>((ref) {
  // Watch STATE so provider auto-recreates when connection status changes
  ref.watch(connectionProvider);
  final conn = ref.read(connectionProvider.notifier);
  return TerminalNotifier(conn.wsClient);
});
