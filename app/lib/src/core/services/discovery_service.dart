import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DiscoveredServer {
  final String host;
  final int port;
  final String name;
  final DateTime lastSeen;

  DiscoveredServer({
    required this.host,
    required this.port,
    required this.name,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  @override
  bool operator ==(Object other) =>
      other is DiscoveredServer && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);
}

class DiscoveryService {
  static const int broadcastPort = 41234;
  static const Duration timeout = Duration(seconds: 10);

  RawDatagramSocket? _socket;
  final _serversController = StreamController<List<DiscoveredServer>>.broadcast();
  final Map<String, DiscoveredServer> _servers = {};
  Timer? _cleanupTimer;

  Stream<List<DiscoveredServer>> get servers => _serversController.stream;
  List<DiscoveredServer> get currentServers => _servers.values.toList();

  Future<void> start() async {
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, broadcastPort);
    _socket!.broadcastEnabled = true;

    _socket!.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();
        if (datagram == null) return;

        try {
          final data = json.decode(utf8.decode(datagram.data));
          if (data['service'] == 'clauderemote') {
            final server = DiscoveredServer(
              host: data['host'] as String,
              port: data['port'] as int,
              name: data['name'] as String,
            );
            _servers[server.host] = server;
            _serversController.add(_servers.values.toList());
          }
        } catch (_) {}
      }
    });

    // Remove stale servers
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      _servers.removeWhere((_, s) => now.difference(s.lastSeen) > timeout);
      _serversController.add(_servers.values.toList());
    });
  }

  void stop() {
    _cleanupTimer?.cancel();
    _socket?.close();
    _socket = null;
    _servers.clear();
  }

  void dispose() {
    stop();
    _serversController.close();
  }
}
