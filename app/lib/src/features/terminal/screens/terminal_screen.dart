import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';
import '../providers/terminal_provider.dart';

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  int _activeTab = 0;
  double _fontSize = 14;

  @override
  void initState() {
    super.initState();
    // Create first session if none exist
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sessions = ref.read(terminalProvider);
      if (sessions.isEmpty) {
        ref.read(terminalProvider.notifier).createSession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(terminalProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terminal'),
        titleTextStyle: theme.textTheme.titleMedium,
        toolbarHeight: 40,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: 'New session',
            onPressed: () async {
              await ref.read(terminalProvider.notifier).createSession();
              setState(() => _activeTab = sessions.length);
            },
          ),
          IconButton(
            icon: const Icon(Icons.text_decrease, size: 20),
            onPressed: () => setState(() => _fontSize = (_fontSize - 1).clamp(8, 24)),
          ),
          IconButton(
            icon: const Icon(Icons.text_increase, size: 20),
            onPressed: () => setState(() => _fontSize = (_fontSize + 1).clamp(8, 24)),
          ),
        ],
        bottom: sessions.length > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(36),
                child: SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: sessions.length,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemBuilder: (context, i) {
                      final isActive = i == _activeTab;
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: ChoiceChip(
                          label: Text('Session ${i + 1}'),
                          selected: isActive,
                          onSelected: (_) => setState(() => _activeTab = i),
                          labelStyle: TextStyle(fontSize: 12),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    },
                  ),
                ),
              )
            : null,
      ),
      body: sessions.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _activeTab.clamp(0, sessions.length - 1),
                    children: sessions.map((session) {
                      return TerminalView(
                        session.terminal,
                        textStyle: TerminalStyle(fontSize: _fontSize),
                        theme: TerminalThemes.whiteOnBlack,
                        autofocus: true,
                      );
                    }).toList(),
                  ),
                ),
                // Special keys toolbar
                _SpecialKeysBar(
                  onKey: (data) {
                    if (sessions.isNotEmpty) {
                      final idx = _activeTab.clamp(0, sessions.length - 1);
                      ref.read(terminalProvider.notifier).sendInput(
                            sessions[idx].sessionId,
                            data,
                          );
                    }
                  },
                ),
              ],
            ),
    );
  }
}

class _SpecialKeysBar extends StatelessWidget {
  final void Function(String data) onKey;

  const _SpecialKeysBar({required this.onKey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _key('ESC', '\x1b'),
            _key('TAB', '\t'),
            _key('CTRL', null, isModifier: true),
            _divider(),
            _key('\u2191', '\x1b[A'),  // Up arrow
            _key('\u2193', '\x1b[B'),  // Down arrow
            _key('\u2190', '\x1b[D'),  // Left arrow
            _key('\u2192', '\x1b[C'),  // Right arrow
            _divider(),
            _key('|', '|'),
            _key('/', '/'),
            _key('~', '~'),
            _key('-', '-'),
            _key('_', '_'),
            _key('Ctrl+C', '\x03'),
            _key('Ctrl+D', '\x04'),
            _key('Ctrl+Z', '\x1a'),
            _key('Ctrl+L', '\x0c'),
          ],
        ),
      ),
    );
  }

  Widget _key(String label, String? data, {bool isModifier = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: data != null ? () => onKey(data) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade600),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isModifier ? Colors.orange : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SizedBox(
            height: 20,
            child: VerticalDivider(width: 1, color: Colors.grey.shade600)),
      );
}
