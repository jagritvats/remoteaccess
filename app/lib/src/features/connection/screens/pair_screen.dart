import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/connection_provider.dart';

class PairScreen extends ConsumerStatefulWidget {
  final String? host;
  final int? port;
  final String? baseUrl; // For remote/tunnel connections
  final String serverName;

  const PairScreen({
    super.key,
    this.host,
    this.port,
    this.baseUrl,
    required this.serverName,
  });

  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Enter PIN')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Icon(Icons.lock_outline, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Pair with ${widget.serverName}',
                style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Enter the 6-digit PIN shown on your PC',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 40),

            // PIN input boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (i) => Container(
                width: 48,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: theme.textTheme.headlineMedium,
                  decoration: InputDecoration(
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) {
                    if (value.isNotEmpty && i < 5) {
                      _focusNodes[i + 1].requestFocus();
                    }
                    if (value.isEmpty && i > 0) {
                      _focusNodes[i - 1].requestFocus();
                    }
                    // Auto-submit when all filled
                    if (_controllers.every((c) => c.text.isNotEmpty)) {
                      _submit();
                    }
                  },
                ),
              )),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],

            const SizedBox(height: 32),

            if (_loading)
              const CircularProgressIndicator()
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Connect'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final pin = _controllers.map((c) => c.text).join();
    if (pin.length != 6) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final notifier = ref.read(connectionProvider.notifier);
    final bool success;
    if (widget.baseUrl != null) {
      success = await notifier.pairWithUrl(widget.baseUrl!, pin);
    } else {
      success = await notifier.pair(
        widget.host!,
        widget.port ?? 8443,
        pin,
      );
    }

    if (!mounted) return;

    if (success) {
      context.go('/dashboard');
    } else {
      setState(() {
        _loading = false;
        _error = 'Invalid PIN. Please try again.';
        for (final c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }
}
