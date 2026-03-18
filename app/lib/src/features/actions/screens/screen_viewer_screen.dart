import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/connection_provider.dart';

class ScreenViewerScreen extends ConsumerStatefulWidget {
  const ScreenViewerScreen({super.key});

  @override
  ConsumerState<ScreenViewerScreen> createState() => _ScreenViewerScreenState();
}

class _ScreenViewerScreenState extends ConsumerState<ScreenViewerScreen> {
  Uint8List? _currentFrame;
  Timer? _refreshTimer;
  double _fps = 1;
  bool _paused = false;
  StreamSubscription? _binarySub;

  @override
  void initState() {
    super.initState();
    _startCapture();
  }

  void _startCapture() {
    final ws = ref.read(connectionProvider.notifier).wsClient;
    if (ws == null) return;

    _binarySub = ws.binaryMessages.listen((data) {
      if (mounted) {
        setState(() => _currentFrame = data);
      }
    });

    _requestFrame();
    _scheduleRefresh();
  }

  void _requestFrame() {
    final ws = ref.read(connectionProvider.notifier).wsClient;
    ws?.sendTyped('screenCapture');
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    if (!_paused) {
      _refreshTimer = Timer.periodic(
        Duration(milliseconds: (1000 / _fps).round()),
        (_) => _requestFrame(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Screen Viewer'),
        actions: [
          IconButton(
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
            onPressed: () {
              setState(() => _paused = !_paused);
              if (_paused) {
                _refreshTimer?.cancel();
              } else {
                _scheduleRefresh();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _requestFrame,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentFrame != null
                ? InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.memory(
                        _currentFrame!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('Waiting for screen capture...',
                            style: theme.textTheme.bodyLarge),
                      ],
                    ),
                  ),
          ),
          // FPS control
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                const Icon(Icons.speed, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _fps,
                    min: 0.5,
                    max: 5,
                    divisions: 9,
                    label: '${_fps.toStringAsFixed(1)} fps',
                    onChanged: (v) {
                      setState(() => _fps = v);
                      _scheduleRefresh();
                    },
                  ),
                ),
                Text('${_fps.toStringAsFixed(1)} fps',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _binarySub?.cancel();
    super.dispose();
  }
}
