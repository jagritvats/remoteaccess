import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/connection_provider.dart';

class ActionsScreen extends ConsumerWidget {
  const ActionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Actions'),
        titleTextStyle: theme.textTheme.titleMedium,
        toolbarHeight: 40,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Power actions
          Text('Power', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.6,
            children: [
              _ActionCard(
                icon: Icons.lock_outline,
                label: 'Lock',
                color: Colors.blue,
                onTap: () => _confirmAction(context, ref, 'Lock your PC?', () {
                  ref.read(connectionProvider.notifier).apiClient?.lock();
                }),
              ),
              _ActionCard(
                icon: Icons.bedtime_outlined,
                label: 'Sleep',
                color: Colors.indigo,
                onTap: () => _confirmAction(context, ref, 'Put PC to sleep?', () {
                  ref.read(connectionProvider.notifier).apiClient?.sleep();
                }),
              ),
              _ActionCard(
                icon: Icons.restart_alt,
                label: 'Restart',
                color: Colors.orange,
                onTap: () => _confirmAction(context, ref, 'Restart your PC?', () {
                  ref.read(connectionProvider.notifier).apiClient?.restart();
                }),
              ),
              _ActionCard(
                icon: Icons.power_settings_new,
                label: 'Shutdown',
                color: Colors.red,
                onTap: () => _confirmAction(context, ref, 'Shut down your PC?', () {
                  ref.read(connectionProvider.notifier).apiClient?.shutdown();
                }),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tools
          Text('Tools', style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          )),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.screenshot_monitor),
              title: const Text('Screen Viewer'),
              subtitle: const Text('See what\'s on your PC screen'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => context.push('/screen-viewer'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('Get Clipboard'),
              subtitle: const Text('Copy PC clipboard to phone'),
              trailing: const Icon(Icons.download),
              onTap: () async {
                try {
                  final text = await ref
                      .read(connectionProvider.notifier)
                      .apiClient
                      ?.getClipboard();
                  if (text != null && text.isNotEmpty && context.mounted) {
                    await Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Clipboard copied to phone')),
                    );
                  }
                } catch (_) {}
              },
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Send Clipboard'),
              subtitle: const Text('Send phone clipboard to PC'),
              trailing: const Icon(Icons.upload),
              onTap: () async {
                try {
                  final data = await Clipboard.getData('text/plain');
                  if (data?.text != null) {
                    await ref
                        .read(connectionProvider.notifier)
                        .apiClient
                        ?.setClipboard(data!.text!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Clipboard sent to PC')),
                      );
                    }
                  }
                } catch (_) {}
              },
            ),
          ),
          const SizedBox(height: 24),

          // Settings
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () => context.push('/settings'),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAction(
      BuildContext context, WidgetRef ref, String message, VoidCallback action) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              action();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Action sent')),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(label, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}
