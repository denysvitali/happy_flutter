import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path_util;

import '../../core/components/app_empty_state.dart';
import '../../core/components/tablet/embedded_pane.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/sync_service.dart';

class SessionFileEntry {
  const SessionFileEntry({
    required this.path,
    required this.operation,
    required this.state,
  });

  final String path;
  final String operation;
  final String state;
}

/// Builds the latest per-path file index from normalized tool-call rows.
List<SessionFileEntry> projectSessionFiles(
  Iterable<Map<String, dynamic>> messages,
) {
  final byPath = <String, SessionFileEntry>{};
  for (final message in messages) {
    if (message['kind'] != 'tool-call') continue;
    final operation = message['name']?.toString() ?? '';
    if (!_fileOperations.contains(operation.toLowerCase())) continue;
    final input = message['input'];
    if (input is! Map) continue;
    final rawPath = input['file_path'] ?? input['filePath'] ?? input['path'];
    if (rawPath is! String || rawPath.trim().isEmpty) continue;
    final normalized = path_util.normalize(rawPath.trim());
    byPath.remove(normalized);
    byPath[normalized] = SessionFileEntry(
      path: normalized,
      operation: operation,
      state: message['state']?.toString() ?? 'completed',
    );
  }
  return byPath.values.toList(growable: false).reversed.toList(growable: false);
}

const _fileOperations = {'read', 'write', 'edit', 'multiedit', 'notebookedit'};

/// Screen that shows files read or changed by tools in this session.
class SessionFilesScreen extends ConsumerStatefulWidget {
  const SessionFilesScreen({
    required this.sessionId,
    this.embedded = false,
    this.onClose,
    super.key,
  });

  final String sessionId;
  final bool embedded;
  final VoidCallback? onClose;

  @override
  ConsumerState<SessionFilesScreen> createState() => _SessionFilesScreenState();
}

class _SessionFilesScreenState extends ConsumerState<SessionFilesScreen> {
  StreamSubscription<String>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _messageSubscription = sync.onSessionMessagesChanged.listen((sessionId) {
      if (mounted && sessionId == widget.sessionId) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_messageSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(
      sessionsNotifierProvider.select((sessions) => sessions[widget.sessionId]),
    );
    final files = session == null
        ? const <SessionFileEntry>[]
        : projectSessionFiles(sync.messagesForSession(widget.sessionId));
    final Widget body;
    if (session == null) {
      body = const _SessionNotFound();
    } else if (files.isEmpty) {
      body = const _EmptyFilesView();
    } else {
      body = ListView.separated(
        itemCount: files.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final file = files[index];
          return ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(path_util.basename(file.path)),
            subtitle: Text(
              file.path,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(file.operation),
            onTap: () => context.pushNamed(
              'session-file',
              pathParameters: {'sessionId': widget.sessionId},
              extra: <String, dynamic>{'path': file.path},
            ),
          );
        },
      );
    }
    return EmbeddedPaneShell(
      title: context.l10n.sessionFilesTitle,
      body: body,
      embedded: widget.embedded,
      onClose: widget.onClose,
      appBarActions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: context.l10n.commonRefresh,
          onPressed: () => unawaited(sync.fetchMessages(widget.sessionId)),
        ),
      ],
    );
  }
}

class _SessionNotFound extends StatelessWidget {
  const _SessionNotFound();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline,
      title: context.l10n.sessionFilesNotFound,
    );
  }
}

class _EmptyFilesView extends StatelessWidget {
  const _EmptyFilesView();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.folder_open_outlined,
      title: context.l10n.sessionFilesEmpty,
      subtitle: context.l10n.sessionFilesEmptySubtitle,
    );
  }
}
