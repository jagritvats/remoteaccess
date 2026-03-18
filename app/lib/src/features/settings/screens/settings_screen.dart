import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/connection_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Connection',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      )),
                  const SizedBox(height: 12),
                  _InfoRow('Server', connection.serverName ?? 'Unknown'),
                  _InfoRow('Address', connection.baseUrl ?? '—'),
                  _InfoRow('Status',
                      connection.isConnected ? 'Connected' : 'Disconnected'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Disconnect
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Disconnect'),
                    content: const Text(
                        'Disconnect from this server? You will need to re-pair.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await ref.read(connectionProvider.notifier).disconnect();
                  if (context.mounted) context.go('/discover');
                }
              },
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect'),
            ),
          ),
          const SizedBox(height: 32),

          Center(
            child: Text(
              'ClaudeRemote v1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  )),
        ],
      ),
    );
  }
}
