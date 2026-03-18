import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/connection_provider.dart';

class FileEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;

  FileEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size = 0,
    this.modified,
  });

  factory FileEntry.fromJson(Map<String, dynamic> json) {
    return FileEntry(
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      isDirectory: json['isDirectory'] as bool? ?? false,
      size: (json['size'] as num?)?.toInt() ?? 0,
      modified: json['modified'] != null
          ? DateTime.tryParse(json['modified'] as String)
          : null,
    );
  }

  String get sizeFormatted {
    if (isDirectory) return '';
    if (size < 1024) return '$size B';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1073741824) return '${(size / 1048576).toStringAsFixed(1)} MB';
    return '${(size / 1073741824).toStringAsFixed(1)} GB';
  }
}

class FileBrowserState {
  final String? currentPath;
  final List<FileEntry> entries;
  final bool loading;
  final String? error;

  const FileBrowserState({
    this.currentPath,
    this.entries = const [],
    this.loading = false,
    this.error,
  });

  FileBrowserState copyWith({
    String? currentPath,
    List<FileEntry>? entries,
    bool? loading,
    String? error,
  }) {
    return FileBrowserState(
      currentPath: currentPath ?? this.currentPath,
      entries: entries ?? this.entries,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  List<String> get breadcrumbs {
    if (currentPath == null) return ['Drives'];
    final parts = currentPath!.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).toList();
    return ['Drives', ...parts];
  }
}

class FileBrowserNotifier extends StateNotifier<FileBrowserState> {
  final ConnectionNotifier _conn;

  FileBrowserNotifier(this._conn) : super(const FileBrowserState()) {
    navigate(null); // Start with drives
  }

  Future<void> navigate(String? path) async {
    state = state.copyWith(loading: true, error: null, currentPath: path);
    try {
      final api = _conn.apiClient;
      if (api == null) throw Exception('Not connected');

      final data = await api.listFiles(path: path);
      final entries = data
          .map((e) => FileEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      // Sort: directories first, then by name
      entries.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      state = state.copyWith(entries: entries, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> goUp() async {
    if (state.currentPath == null) return;
    final parts = state.currentPath!.split(RegExp(r'[/\\]'));
    if (parts.length <= 2) {
      // At root like "C:\" → go to drives
      await navigate(null);
    } else {
      parts.removeLast();
      await navigate(parts.join('\\'));
    }
  }

  Future<void> createDirectory(String name) async {
    final path = state.currentPath != null
        ? '${state.currentPath}\\$name'
        : name;
    await _conn.apiClient?.createDirectory(path);
    await navigate(state.currentPath);
  }

  Future<void> delete(String path) async {
    await _conn.apiClient?.deleteFile(path);
    await navigate(state.currentPath);
  }

  Future<void> rename(String oldPath, String newName) async {
    final dir = oldPath.substring(0, oldPath.lastIndexOf(RegExp(r'[/\\]')) + 1);
    await _conn.apiClient?.renameFile(oldPath, '$dir$newName');
    await navigate(state.currentPath);
  }
}

final fileBrowserProvider =
    StateNotifierProvider<FileBrowserNotifier, FileBrowserState>((ref) {
  final conn = ref.watch(connectionProvider.notifier);
  return FileBrowserNotifier(conn);
});
