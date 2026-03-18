import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

import '../../core/components/app_empty_state.dart';

/// Screen that displays the content of a file fetched from the
/// session's remote machine.
///
/// When [content] is provided it is shown immediately.  Otherwise the
/// screen fetches the file from the daemon via [Sync.machineReadFile].
class SessionFileViewerScreen extends StatefulWidget {
  /// Creates a [SessionFileViewerScreen].
  const SessionFileViewerScreen({
    required this.path,
    required this.sessionId,
    this.content,
    super.key,
  });

  /// The full file path to display.
  final String path;

  /// The session whose machine should be used to fetch the file.
  final String sessionId;

  /// Optional pre-loaded file content.
  final String? content;

  @override
  State<SessionFileViewerScreen> createState() =>
      _SessionFileViewerScreenState();
}

class _SessionFileViewerScreenState extends State<SessionFileViewerScreen> {
  String? _content;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.content != null && widget.content!.isNotEmpty) {
      _content = widget.content;
    } else {
      _fetchFile();
    }
  }

  Future<void> _fetchFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = sync.sessions[widget.sessionId];
      final machineId = session?.metadata?.machineId;
      if (machineId == null || machineId.isEmpty) {
        setState(() {
          _error = 'No machine associated with this session';
          _loading = false;
        });
        return;
      }

      final response = await sync.machineReadFile(
        machineId: machineId,
        filePath: widget.path,
      );

      if (!mounted) return;

      if (response.success) {
        // The daemon returns base64-encoded content.
        final decoded = _tryBase64Decode(response.content);
        setState(() {
          _content = decoded;
          _loading = false;
        });
      } else {
        setState(() {
          _error = response.error ?? 'Failed to read file';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Attempts base64 decoding; returns the original string if it is not
  /// valid base64 (some tool responses return plain text directly).
  static String _tryBase64Decode(String input) {
    try {
      final decoded = base64Decode(input);
      return utf8.decode(decoded);
    } catch (_) {
      return input;
    }
  }

  /// Extracts the file name from the full path.
  String get _fileName {
    if (widget.path.isEmpty) return 'File';
    final segments =
        widget.path.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isNotEmpty ? segments.last : widget.path;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _fileName,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Path header bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.smd,
            ),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.path,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: AppFontSize.sm,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: AppBorder.hairline,
            color: theme.colorScheme.outlineVariant,
          ),

          // File content
          Expanded(
            child: _buildContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load file',
        subtitle: _error,
      );
    }

    if (_content == null || _content!.isEmpty) {
      return AppEmptyState(
        icon: Icons.description_outlined,
        title: 'No content',
        subtitle: 'The file is empty or could not be read.',
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        padding: AppScreenPadding.standard,
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(
            _content!,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontSize: AppFontSize.md,
              height: AppLineHeight.relaxed,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
