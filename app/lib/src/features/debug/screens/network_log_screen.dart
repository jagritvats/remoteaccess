import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/network_log.dart';

class NetworkLogScreen extends StatefulWidget {
  const NetworkLogScreen({super.key});

  @override
  State<NetworkLogScreen> createState() => _NetworkLogScreenState();
}

class _NetworkLogScreenState extends State<NetworkLogScreen> {
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = NetworkLog.instance.onEntry.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case 'HTTP':
        return Colors.blue;
      case 'WS':
        return Colors.green;
      case 'ERROR':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = NetworkLog.instance.entries.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              NetworkLog.instance.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(child: Text('No network activity yet'))
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                final time =
                    '${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}:${e.time.second.toString().padLeft(2, '0')}';

                return ExpansionTile(
                  leading: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _tagColor(e.tag).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      e.tag,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _tagColor(e.tag),
                      ),
                    ),
                  ),
                  title: Text(e.summary, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(time, style: const TextStyle(fontSize: 11)),
                  children: [
                    if (e.detail != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(
                          e.detail!,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
