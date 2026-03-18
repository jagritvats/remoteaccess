import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import '../../../core/providers/connection_provider.dart';
import '../providers/system_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(systemStatsProvider);
    final connection = ref.watch(connectionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(connection.serverName ?? 'Dashboard'),
        actions: [
          IconButton(
            icon: Icon(
              connection.isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: connection.isConnected ? Colors.green : Colors.red,
            ),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(systemStatsProvider.notifier).unsubscribe();
          await Future.delayed(const Duration(milliseconds: 300));
          ref.read(systemStatsProvider.notifier).subscribe();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Connection status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.computer,
                        size: 40, color: theme.colorScheme.primary),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(stats.hostname,
                              style: theme.textTheme.titleMedium),
                          Text('Uptime: ${stats.uptime}',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: connection.isConnected
                            ? Colors.green.withAlpha(30)
                            : Colors.red.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        connection.isConnected ? 'Connected' : 'Offline',
                        style: TextStyle(
                          color: connection.isConnected
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // CPU & RAM row
            Row(
              children: [
                // CPU
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CircularPercentIndicator(
                            radius: 50,
                            lineWidth: 8,
                            percent: (stats.cpuUsage / 100).clamp(0.0, 1.0),
                            center: Text(
                              '${stats.cpuUsage.toStringAsFixed(0)}%',
                              style: theme.textTheme.titleLarge,
                            ),
                            progressColor: _getUsageColor(stats.cpuUsage / 100),
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            animation: true,
                            animateFromLastPercent: true,
                            circularStrokeCap: CircularStrokeCap.round,
                          ),
                          const SizedBox(height: 12),
                          Text('CPU', style: theme.textTheme.titleSmall),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // RAM
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          CircularPercentIndicator(
                            radius: 50,
                            lineWidth: 8,
                            percent: stats.ramPercent.clamp(0.0, 1.0),
                            center: Text(
                              '${(stats.ramPercent * 100).toStringAsFixed(0)}%',
                              style: theme.textTheme.titleLarge,
                            ),
                            progressColor: _getUsageColor(stats.ramPercent),
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            animation: true,
                            animateFromLastPercent: true,
                            circularStrokeCap: CircularStrokeCap.round,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${(stats.usedRamMb / 1024).toStringAsFixed(1)} / ${(stats.totalRamMb / 1024).toStringAsFixed(1)} GB',
                            style: theme.textTheme.bodySmall,
                          ),
                          Text('RAM', style: theme.textTheme.titleSmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Disks
            Text('Storage', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ...stats.disks.map((disk) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(disk.drive,
                                style: theme.textTheme.titleSmall),
                            Text(
                              '${disk.usedGb.toStringAsFixed(1)} / ${disk.totalGb.toStringAsFixed(1)} GB',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearPercentIndicator(
                          padding: EdgeInsets.zero,
                          lineHeight: 8,
                          percent: disk.usedPercent.clamp(0.0, 1.0),
                          progressColor: _getUsageColor(disk.usedPercent),
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          barRadius: const Radius.circular(4),
                          animation: true,
                          animateFromLastPercent: true,
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Color _getUsageColor(double percent) {
    if (percent < 0.6) return Colors.green;
    if (percent < 0.8) return Colors.orange;
    return Colors.red;
  }
}
