import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/connection_provider.dart';
import '../providers/file_provider.dart';

class FileBrowserScreen extends ConsumerWidget {
  const FileBrowserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fileBrowserProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Files'),
        titleTextStyle: theme.textTheme.titleMedium,
        toolbarHeight: 40,
      ),
      body: Column(
        children: [
          // Breadcrumb bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                if (state.currentPath != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: () =>
                        ref.read(fileBrowserProvider.notifier).goUp(),
                    visualDensity: VisualDensity.compact,
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: state.breadcrumbs.asMap().entries.map((entry) {
                        final i = entry.key;
                        final crumb = entry.value;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (i > 0)
                              Icon(Icons.chevron_right,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant),
                            InkWell(
                              onTap: () {
                                if (i == 0) {
                                  ref
                                      .read(fileBrowserProvider.notifier)
                                      .navigate(null);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 2),
                                child: Text(
                                  crumb,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: i == state.breadcrumbs.length - 1
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight:
                                        i == state.breadcrumbs.length - 1
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // File list
          Expanded(
            child: state.loading
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48,
                                color: theme.colorScheme.error),
                            const SizedBox(height: 8),
                            Text('Error loading files',
                                style: theme.textTheme.bodyLarge),
                            TextButton(
                              onPressed: () => ref
                                  .read(fileBrowserProvider.notifier)
                                  .navigate(state.currentPath),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ref
                            .read(fileBrowserProvider.notifier)
                            .navigate(state.currentPath),
                        child: ListView.builder(
                          itemCount: state.entries.length,
                          itemBuilder: (context, i) {
                            final entry = state.entries[i];
                            return ListTile(
                              leading: Icon(
                                entry.isDirectory
                                    ? Icons.folder
                                    : _getFileIcon(entry.name),
                                color: entry.isDirectory
                                    ? Colors.amber
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              title: Text(entry.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: entry.isDirectory
                                  ? null
                                  : Text(entry.sizeFormatted,
                                      style: theme.textTheme.bodySmall),
                              trailing: entry.isDirectory
                                  ? const Icon(Icons.chevron_right, size: 20)
                                  : null,
                              onTap: entry.isDirectory
                                  ? () => ref
                                      .read(fileBrowserProvider.notifier)
                                      .navigate(entry.path)
                                  : _isViewable(entry.name)
                                      ? () => context.push('/file-viewer',
                                          extra: {
                                            'path': entry.path,
                                            'fileName': entry.name,
                                          })
                                      : null,
                              onLongPress: () => _showContextMenu(
                                  context, ref, entry),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: state.currentPath != null
          ? FloatingActionButton(
              onPressed: () => _showAddMenu(context, ref, state.currentPath!),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  static const _viewableExtensions = {
    'txt', 'log', 'md', 'json', 'xml', 'yaml', 'yml', 'toml', 'ini', 'cfg',
    'conf', 'csv', 'html', 'htm', 'css', 'js', 'ts', 'dart', 'py', 'cs',
    'java', 'cpp', 'c', 'h', 'rs', 'go', 'rb', 'php', 'sh', 'bat', 'ps1',
    'sql', 'r', 'swift', 'kt', 'gradle', 'makefile', 'dockerfile', 'env',
    'gitignore', 'editorconfig', 'properties', 'csproj', 'sln', 'pubspec',
  };

  bool _isViewable(String name) {
    final ext = name.split('.').last.toLowerCase();
    // Also handle dotfiles like .gitignore (no extension)
    return _viewableExtensions.contains(ext) || !name.contains('.');
  }

  IconData _getFileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf,
      'jpg' || 'jpeg' || 'png' || 'gif' || 'bmp' || 'webp' => Icons.image,
      'mp4' || 'avi' || 'mkv' || 'mov' => Icons.video_file,
      'mp3' || 'wav' || 'flac' || 'aac' => Icons.audio_file,
      'zip' || 'rar' || '7z' || 'tar' || 'gz' => Icons.archive,
      'txt' || 'log' || 'md' => Icons.description,
      'dart' || 'py' || 'js' || 'ts' || 'cs' || 'java' => Icons.code,
      'exe' || 'msi' => Icons.apps,
      _ => Icons.insert_drive_file,
    };
  }

  void _showContextMenu(
      BuildContext context, WidgetRef ref, FileEntry entry) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, ref, entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title:
                  const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirm(context, ref, entry);
              },
            ),
            if (!entry.isDirectory)
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Download'),
                onTap: () {
                  Navigator.pop(ctx);
                  // Download handling would go here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Download started...')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(
      BuildContext context, WidgetRef ref, FileEntry entry) {
    final controller = TextEditingController(text: entry.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(fileBrowserProvider.notifier)
                  .rename(entry.path, controller.text);
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(
      BuildContext context, WidgetRef ref, FileEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${entry.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(fileBrowserProvider.notifier).delete(entry.path);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddMenu(BuildContext context, WidgetRef ref, String currentPath) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder),
              title: const Text('New Folder'),
              onTap: () {
                Navigator.pop(ctx);
                _showNewFolderDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Upload File'),
              onTap: () async {
                Navigator.pop(ctx);
                final result =
                    await FilePicker.platform.pickFiles(allowMultiple: false);
                if (result != null && result.files.single.path != null) {
                  final file = result.files.single;
                  await ref
                      .read(connectionProvider.notifier)
                      .apiClient
                      ?.uploadFile(currentPath, file.path!, file.name);
                  ref
                      .read(fileBrowserProvider.notifier)
                      .navigate(currentPath);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNewFolderDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Folder name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(fileBrowserProvider.notifier)
                  .createDirectory(controller.text);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
