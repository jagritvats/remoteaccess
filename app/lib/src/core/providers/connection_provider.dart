import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_client.dart';
import '../services/websocket_client.dart';

class ConnectionState {
  final String? baseUrl; // e.g. http://192.168.1.5:8443 or https://abc.ngrok.io
  final String? token;
  final String? serverName;
  final bool isConnected;

  const ConnectionState({
    this.baseUrl,
    this.token,
    this.serverName,
    this.isConnected = false,
  });

  ConnectionState copyWith({
    String? baseUrl,
    String? token,
    String? serverName,
    bool? isConnected,
  }) {
    return ConnectionState(
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
      serverName: serverName ?? this.serverName,
      isConnected: isConnected ?? this.isConnected,
    );
  }
}

class ConnectionNotifier extends StateNotifier<ConnectionState> {
  static const _storage = FlutterSecureStorage();
  ApiClient? _apiClient;
  WebSocketClient? _wsClient;

  ConnectionNotifier() : super(const ConnectionState()) {
    _loadSaved();
  }

  ApiClient? get apiClient => _apiClient;
  WebSocketClient? get wsClient => _wsClient;

  Future<void> _loadSaved() async {
    final baseUrl = await _storage.read(key: 'baseUrl');
    final token = await _storage.read(key: 'token');
    final serverName = await _storage.read(key: 'serverName');

    if (baseUrl != null && token != null) {
      state = ConnectionState(
        baseUrl: baseUrl,
        token: token,
        serverName: serverName,
      );
      await connect();
    }
  }

  /// Build a baseUrl from host:port (LAN / emulator)
  static String buildBaseUrl(String host, int port) => 'http://$host:$port';

  /// Pair using host + port (LAN / emulator)
  Future<bool> pair(String host, int port, String pin) async {
    return pairWithUrl(buildBaseUrl(host, port), pin);
  }

  /// Pair using full URL (tunnel / remote)
  Future<bool> pairWithUrl(String baseUrl, String pin) async {
    // Normalize: remove trailing slash
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);

    _apiClient = ApiClient(baseUrl: baseUrl);

    try {
      final result = await _apiClient!.pair(pin, 'ClaudeRemote App');
      final token = result['token'] as String;
      final serverName = result['serverName'] as String;

      _apiClient!.setToken(token);

      await _storage.write(key: 'baseUrl', value: baseUrl);
      await _storage.write(key: 'token', value: token);
      await _storage.write(key: 'serverName', value: serverName);

      state = ConnectionState(
        baseUrl: baseUrl,
        token: token,
        serverName: serverName,
      );

      await connect();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> connect() async {
    if (state.baseUrl == null || state.token == null) return;

    _apiClient ??= ApiClient(baseUrl: state.baseUrl!);
    _apiClient!.setToken(state.token!);

    _wsClient?.disconnect();
    _wsClient = WebSocketClient(
      baseUrl: state.baseUrl!,
      token: state.token!,
    );

    _wsClient!.statusStream.listen((status) {
      state = state.copyWith(
        isConnected: status == ConnectionStatus.connected,
      );
    });

    await _wsClient!.connect();
  }

  Future<void> disconnect() async {
    _wsClient?.disconnect();
    _apiClient?.clearToken();
    await _storage.deleteAll();
    state = const ConnectionState();
  }

  @override
  void dispose() {
    _wsClient?.dispose();
    super.dispose();
  }
}

final connectionProvider =
    StateNotifierProvider<ConnectionNotifier, ConnectionState>((ref) {
  return ConnectionNotifier();
});
