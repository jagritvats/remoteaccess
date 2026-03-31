import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../../../core/providers/connection_provider.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/websocket_client.dart';

class TerminalSession {
  final String sessionId;
  final Terminal terminal;

  TerminalSession({required this.sessionId, required this.terminal});
}

class TerminalNotifier extends StateNotifier<List<TerminalSession>> {
  final WebSocketClient? _ws;
  final ApiClient? _api;
  StreamSubscription? _outputSub;
  StreamSubscription? _createdSub;
  Completer<String>? _createCompleter;

  TerminalNotifier(this._ws, this._api) : super([]) {
    _listenForOutput();
    _reattachExistingSessions();
  }

  /// On provider rebuild (after reconnect), re-attach any server sessions.
  Future<void> _reattachExistingSessions() async {
    final remoteSessions = await getRemoteSessions();
    for (final sid in remoteSessions) {
      if (!state.any((s) => s.sessionId == sid)) {
        await attachSession(sid);
      }
    }
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

  /// Create a new terminal session on the server.
  Future<TerminalSession> createSession() async {
    _createCompleter = Completer<String>();
    // Server will create ConPTY at default 80x24; xterm.onResize will fix it immediately
    _ws?.sendTyped('terminalCreate');

    final sessionId = await _createCompleter!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => 'fallback-${DateTime.now().millisecondsSinceEpoch}',
    );

    return _wireSession(sessionId);
  }

  /// Attach to an existing terminal session on the server.
  Future<TerminalSession> attachSession(String sessionId) async {
    _createCompleter = Completer<String>();
    _ws?.sendTyped('terminalAttach', {'sessionId': sessionId, 'data': ''});

    await _createCompleter!.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => sessionId, // Use the ID we already know
    );

    return _wireSession(sessionId);
  }

  /// Get list of active sessions from server (for resume).
  Future<List<String>> getRemoteSessions() async {
    if (_api == null) return [];
    try {
      final response = await _api.getTerminals();
      return response
          .map((e) => e['sessionId'] as String)
          .toList();
    } catch (_) {
      return [];
    }
  }

  TerminalSession _wireSession(String sessionId) {
    final terminal = Terminal(maxLines: 10000);

    // Wire terminal input → WebSocket
    terminal.onOutput = (data) {
      _ws?.sendTyped('terminalInput', {
        'sessionId': sessionId,
        'data': data,
      });
    };

    // Wire resize events → server (fires on first render + keyboard + rotation)
    terminal.onResize = (w, h, pw, ph) {
      _ws?.sendTyped('terminalResize', {
        'sessionId': sessionId,
        'cols': w,
        'rows': h,
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
    // Don't close sessions on dispose — they persist on the server
    super.dispose();
  }
}

final terminalProvider =
    StateNotifierProvider<TerminalNotifier, List<TerminalSession>>((ref) {
  ref.watch(connectionProvider);
  final conn = ref.read(connectionProvider.notifier);
  return TerminalNotifier(conn.wsClient, conn.apiClient);
});
