import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/connection_provider.dart';
import '../../../core/services/websocket_client.dart';

class SystemStats {
  final double cpuUsage;
  final int totalRamMb;
  final int usedRamMb;
  final List<DiskStats> disks;
  final String hostname;
  final String uptime;

  const SystemStats({
    this.cpuUsage = 0,
    this.totalRamMb = 0,
    this.usedRamMb = 0,
    this.disks = const [],
    this.hostname = '',
    this.uptime = '',
  });

  factory SystemStats.fromJson(Map<String, dynamic> json) {
    return SystemStats(
      cpuUsage: (json['cpuUsage'] as num?)?.toDouble() ?? 0,
      totalRamMb: (json['totalRamMb'] as num?)?.toInt() ?? 0,
      usedRamMb: (json['usedRamMb'] as num?)?.toInt() ?? 0,
      hostname: json['hostname'] as String? ?? '',
      uptime: json['uptime'] as String? ?? '',
      disks: (json['disks'] as List?)
              ?.map((d) => DiskStats.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  double get ramPercent => totalRamMb > 0 ? usedRamMb / totalRamMb : 0;
}

class DiskStats {
  final String drive;
  final double totalGb;
  final double freeGb;

  DiskStats({required this.drive, required this.totalGb, required this.freeGb});

  factory DiskStats.fromJson(Map<String, dynamic> json) {
    return DiskStats(
      drive: json['drive'] as String? ?? '',
      totalGb: (json['totalGb'] as num?)?.toDouble() ?? 0,
      freeGb: (json['freeGb'] as num?)?.toDouble() ?? 0,
    );
  }

  double get usedGb => totalGb - freeGb;
  double get usedPercent => totalGb > 0 ? usedGb / totalGb : 0;
}

class SystemStatsNotifier extends StateNotifier<SystemStats> {
  StreamSubscription? _statsSub;
  StreamSubscription? _statusSub;
  final WebSocketClient? _ws;

  SystemStatsNotifier(this._ws) : super(const SystemStats()) {
    if (_ws == null) return;

    // If already connected, subscribe immediately
    if (_ws.status == ConnectionStatus.connected) {
      subscribe();
    }

    // Also listen for connection status changes to auto-subscribe
    _statusSub = _ws.statusStream.listen((status) {
      if (status == ConnectionStatus.connected) {
        subscribe();
      }
    });
  }

  void subscribe() {
    _statsSub?.cancel();
    if (_ws == null) return;
    _ws.sendTyped('subscribeStats');
    _statsSub = _ws.on('systemStats').listen((msg) {
      if (msg.payload != null && mounted) {
        state = SystemStats.fromJson(msg.payload!);
      }
    });
  }

  void unsubscribe() {
    _ws?.sendTyped('unsubscribeStats');
    _statsSub?.cancel();
    _statsSub = null;
  }

  @override
  void dispose() {
    unsubscribe();
    _statusSub?.cancel();
    super.dispose();
  }
}

final systemStatsProvider =
    StateNotifierProvider<SystemStatsNotifier, SystemStats>((ref) {
  // Watch STATE so provider auto-recreates when connection status changes
  ref.watch(connectionProvider);
  final conn = ref.read(connectionProvider.notifier);
  return SystemStatsNotifier(conn.wsClient);
});
