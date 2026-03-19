import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/dio_factory.dart';
import '../../../core/services/discovery_service.dart';

final _discoveryProvider =
    StateNotifierProvider<_DiscoveryNotifier, List<DiscoveredServer>>((ref) {
  return _DiscoveryNotifier();
});

class _DiscoveryNotifier extends StateNotifier<List<DiscoveredServer>> {
  final _service = DiscoveryService();

  _DiscoveryNotifier() : super([]) {
    _service.servers.listen((servers) {
      if (mounted) state = servers;
    });
    _service.start();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8443');
  final _remoteUrlController = TextEditingController();
  bool _emulatorAvailable = false;
  bool _checkingEmulator = false;

  @override
  void initState() {
    super.initState();
    _checkEmulator();
  }

  Future<void> _checkEmulator() async {
    if (!Platform.isAndroid) return;
    setState(() => _checkingEmulator = true);

    try {
      final dio = DioFactory.create(connectTimeout: const Duration(seconds: 2));
      final response = await dio.get('http://10.0.2.2:8443/api/health');
      if (response.statusCode == 200 && mounted) {
        setState(() => _emulatorAvailable = true);
      }
    } catch (_) {
      // Not running in emulator or server not running on host
    } finally {
      if (mounted) setState(() => _checkingEmulator = false);
    }
  }

  void _goToPair({String? host, int? port, String? baseUrl, String? name}) {
    context.push('/pair', extra: {
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (baseUrl != null) 'baseUrl': baseUrl,
      'name': name ?? host ?? baseUrl ?? 'Server',
    });
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(_discoveryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => context.push('/debug-log'),
        child: const Icon(Icons.bug_report),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Icon(Icons.computer, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('ClaudeRemote',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
            const SizedBox(height: 8),
            Text('Connect to your Windows PC',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 32),

            // ── Emulator shortcut ──
            if (_emulatorAvailable) ...[
              _SectionHeader('Emulator', icon: Icons.phone_android),
              Card(
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  leading: Icon(Icons.laptop,
                      color: theme.colorScheme.onPrimaryContainer),
                  title: Text('Connect to Host PC',
                      style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer)),
                  subtitle: Text('10.0.2.2:8443',
                      style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer
                              .withAlpha(180))),
                  trailing: Icon(Icons.arrow_forward,
                      color: theme.colorScheme.onPrimaryContainer),
                  onTap: () => _goToPair(
                    host: '10.0.2.2',
                    port: 8443,
                    name: 'Host PC (Emulator)',
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else if (_checkingEmulator) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ],

            // ── LAN Discovery ──
            _SectionHeader('Local Network', icon: Icons.wifi),
            if (servers.isNotEmpty)
              ...servers.map((s) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.dns),
                      title: Text(s.name),
                      subtitle: Text('${s.host}:${s.port}'),
                      trailing: const Icon(Icons.arrow_forward),
                      onTap: () => _goToPair(
                        host: s.host,
                        port: s.port,
                        name: s.name,
                      ),
                    ),
                  ))
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text('Scanning...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
            const SizedBox(height: 20),

            // ── Remote (Tunnel) ──
            _SectionHeader('Remote / Tunnel', icon: Icons.cloud_outlined),
            const SizedBox(height: 8),
            TextField(
              controller: _remoteUrlController,
              decoration: InputDecoration(
                hintText: 'https://abc123.ngrok-free.app',
                prefixIcon: const Icon(Icons.link),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _connectRemote,
                ),
              ),
              keyboardType: TextInputType.url,
              onSubmitted: (_) => _connectRemote(),
            ),
            const SizedBox(height: 4),
            Text(
              'ngrok, Cloudflare Tunnel, bore, or any HTTPS URL',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // ── Manual IP ──
            _SectionHeader('Manual', icon: Icons.edit),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      hintText: 'IP Address',
                      prefixIcon: Icon(Icons.wifi),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(hintText: 'Port'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  final host = _hostController.text.trim();
                  final port = int.tryParse(_portController.text) ?? 8443;
                  if (host.isNotEmpty) {
                    _goToPair(host: host, port: port, name: host);
                  }
                },
                icon: const Icon(Icons.link),
                label: const Text('Connect'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _connectRemote() async {
    var url = _remoteUrlController.text.trim();
    if (url.isEmpty) return;
    // Auto-add https:// if no scheme
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    // Validate server is reachable before going to pair screen
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking server...'), duration: Duration(seconds: 10)),
    );

    try {
      final dio = DioFactory.create(
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      );
      final response = await dio.get('$url/api/health');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200) {
        _goToPair(baseUrl: url, name: Uri.tryParse(url)?.host ?? url);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server responded with status ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot reach server: ${e is DioException ? e.message : e}')),
      );
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _remoteUrlController.dispose();
    super.dispose();
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SectionHeader(this.label, {required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            )),
      ],
    );
  }
}
