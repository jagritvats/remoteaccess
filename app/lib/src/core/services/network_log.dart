import 'dart:async';

class NetworkLogEntry {
  final DateTime time;
  final String tag; // "HTTP", "WS", "ERROR"
  final String summary;
  final String? detail;

  NetworkLogEntry({
    required this.tag,
    required this.summary,
    this.detail,
  }) : time = DateTime.now();
}

class NetworkLog {
  static final instance = NetworkLog._();
  NetworkLog._();

  static const _maxEntries = 200;
  final entries = <NetworkLogEntry>[];
  final _controller = StreamController<NetworkLogEntry>.broadcast();

  Stream<NetworkLogEntry> get onEntry => _controller.stream;

  void add(String tag, String summary, [String? detail]) {
    final entry = NetworkLogEntry(tag: tag, summary: summary, detail: detail);
    entries.add(entry);
    if (entries.length > _maxEntries) {
      entries.removeAt(0);
    }
    _controller.add(entry);
  }

  void clear() => entries.clear();
}
