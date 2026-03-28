import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../models/sftp_directory.dart';

/// State for SFTP directories
class SftpState {
  const SftpState({this.directories = const [], this.isLoading = false});

  final List<SftpDirectory> directories;
  final bool isLoading;

  SftpState copyWith({
    List<SftpDirectory>? directories,
    bool? isLoading,
  }) {
    return SftpState(
      directories: directories ?? this.directories,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// SFTP notifier for managing shared directories
class SftpNotifier extends Notifier<SftpState> {
  @override
  SftpState build() {
    _loadDirectories();
    return const SftpState(isLoading: true);
  }

  Future<File> get _configFile async {
    final appDir = await getApplicationSupportDirectory();
    return File('${appDir.path}/sftp_directories.json');
  }

  Future<void> _loadDirectories() async {
    try {
      final file = await _configFile;
      if (await file.exists()) {
        final content = await file.readAsString();
        final jsonList = jsonDecode(content) as List;
        final dirs = jsonList
            .map(
              (j) =>
                  SftpDirectory.fromJson(j as Map<String, dynamic>),
            )
            .toList();
        state = SftpState(directories: dirs);
      } else {
        state = const SftpState();
      }
    } catch (_) {
      state = const SftpState();
    }
  }

  Future<void> addDirectory(SftpDirectory directory) async {
    state = state.copyWith(
      directories: [...state.directories, directory],
    );
    await _save();
  }

  Future<void> updateDirectory(SftpDirectory directory) async {
    final dirs = state.directories
        .map((d) => d.id == directory.id ? directory : d)
        .toList();
    state = state.copyWith(directories: dirs);
    await _save();
  }

  Future<void> removeDirectory(String id) async {
    final dirs =
        state.directories.where((d) => d.id != id).toList();
    state = state.copyWith(directories: dirs);
    await _save();
  }

  Future<void> _save() async {
    try {
      final file = await _configFile;
      final jsonList =
          state.directories.map((d) => d.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (_) {
      // Silently fail on save
    }
  }
}

/// Provider for SFTP state
final sftpNotifierProvider =
    NotifierProvider<SftpNotifier, SftpState>(SftpNotifier.new);

/// Add directory dialog
class AddSftpDirectoryDialog extends StatefulWidget {
  const AddSftpDirectoryDialog({super.key});

  @override
  State<AddSftpDirectoryDialog> createState() =>
      _AddSftpDirectoryDialogState();
}

class _AddSftpDirectoryDialogState extends State<AddSftpDirectoryDialog> {
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  SftpAuthMethod _authMethod = SftpAuthMethod.password;
  SftpClipboardMode _clipboardMode = SftpClipboardMode.off;

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Shared Directory'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Share Name',
                hintText: 'My Project Files',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pathController,
              decoration: const InputDecoration(
                labelText: 'Directory Path',
                hintText: '/home/user/projects',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Port',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SftpAuthMethod>(
              initialValue: _authMethod,
              decoration: const InputDecoration(
                labelText: 'Authentication',
              ),
              items: SftpAuthMethod.values
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _authMethod = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SftpClipboardMode>(
              initialValue: _clipboardMode,
              decoration: const InputDecoration(
                labelText: 'Clipboard Sync',
              ),
              items: SftpClipboardMode.values
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _clipboardMode = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final path = _pathController.text.trim();
            if (name.isEmpty || path.isEmpty) return;

            final directory = SftpDirectory(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              path: path,
              port: int.tryParse(_portController.text) ?? 22,
              authMethod: _authMethod,
              clipboardMode: _clipboardMode,
            );

            Navigator.pop(context, directory);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
