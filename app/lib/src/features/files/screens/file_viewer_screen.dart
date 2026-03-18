import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/connection_provider.dart';

class FileViewerScreen extends ConsumerStatefulWidget {
  final String path;
  final String fileName;

  const FileViewerScreen({
    super.key,
    required this.path,
    required this.fileName,
  });

  @override
  ConsumerState<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends ConsumerState<FileViewerScreen> {
  String? _content;
  bool _loading = true;
  String? _error;
  bool _truncated = false;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(connectionProvider.notifier).apiClient;
      if (api == null) throw Exception('Not connected');

      final result = await api.readFile(widget.path);
      if (mounted) {
        setState(() {
          _content = result['content'] as String? ?? '';
          _truncated = result['truncated'] as bool? ?? false;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        titleTextStyle: theme.textTheme.titleSmall,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: theme.colorScheme.error),
                      const SizedBox(height: 8),
                      Text('Cannot read file',
                          style: theme.textTheme.bodyLarge),
                      const SizedBox(height: 4),
                      Text(_error!,
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: _loadFile, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_truncated)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        color: theme.colorScheme.tertiaryContainer,
                        child: Text(
                          'File truncated (showing first 500KB)',
                          style: TextStyle(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(12),
                          child: SelectableText(
                            _content ?? '',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
