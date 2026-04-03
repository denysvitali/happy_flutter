import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';

import '../../core/components/app_empty_state.dart';
import 'markdown/markdown_view.dart';
import 'syntax_highlighter.dart';

/// Whether [extension] (without dot) is a markdown file.
bool _isMarkdown(String extension) =>
    extension == 'md' || extension == 'markdown' || extension == 'mdx';

/// Extracts the file extension (lowercase, without dot) from [path].
String _extensionOf(String path) {
  final dot = path.lastIndexOf('.');
  if (dot < 0 || dot == path.length - 1) return '';
  return path.substring(dot + 1).toLowerCase();
}

/// View mode for the file viewer.
enum _ViewMode { code, preview }

/// Screen that displays the content of a file fetched from the
/// session's remote machine.
///
/// When [content] is provided it is shown immediately.  Otherwise the
/// screen fetches the file from the daemon via [Sync.machineReadFile].
///
/// Code files are rendered with syntax highlighting and line numbers.
/// Markdown files offer a toggle between rendered preview and source.
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
  bool _copied = false;

  /// Current view mode (only meaningful for markdown files).
  _ViewMode _viewMode = _ViewMode.preview;

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
    } catch (e, st) {
      logger.warning(
        '[SessionFileViewerScreen] machineReadFile failed: '
        'path=${widget.path} $e',
        e,
        st,
      );
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

  /// The detected language for syntax highlighting (null if unknown).
  String? get _language {
    final ext = _extensionOf(widget.path);
    if (ext.isEmpty) return null;
    return detectLanguage(ext);
  }

  bool get _isMd => _isMarkdown(_extensionOf(widget.path));

  Future<void> _copyToClipboard() async {
    if (_content == null) return;
    await Clipboard.setData(ClipboardData(text: _content!));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
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
        actions: [
          // Copy button
          if (_content != null)
            IconButton(
              icon: Icon(
                _copied
                    ? Icons.check_rounded
                    : Icons.content_copy_rounded,
                size: 20,
              ),
              tooltip: _copied ? 'Copied!' : 'Copy file',
              onPressed: _copyToClipboard,
            ),
          // Markdown preview / code toggle
          if (_isMd && _content != null)
            IconButton(
              icon: Icon(
                _viewMode == _ViewMode.preview
                    ? Icons.code_rounded
                    : Icons.visibility_rounded,
                size: 20,
              ),
              tooltip: _viewMode == _ViewMode.preview
                  ? 'View source'
                  : 'View preview',
              onPressed: () => setState(() {
                _viewMode = _viewMode == _ViewMode.preview
                    ? _ViewMode.code
                    : _ViewMode.preview;
              }),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Path header bar
          _PathHeader(path: widget.path, language: _language),
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

    // Markdown preview mode
    if (_isMd && _viewMode == _ViewMode.preview) {
      return Scrollbar(
        child: SingleChildScrollView(
          padding: AppScreenPadding.standard,
          child: SimpleMarkdownView(markdown: _content!),
        ),
      );
    }

    // Syntax-highlighted code view
    final isDark = theme.brightness == Brightness.dark;
    const fontSize = AppFontSize.md;
    const lineHeight = fontSize * 1.5;
    final lineCount = '\n'.allMatches(_content!).length + 1;

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LineNumbers(
                lineCount: lineCount,
                fontSize: fontSize,
                lineHeight: lineHeight,
                isDark: isDark,
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.lg,
                ),
                child: SyntaxHighlighter(
                  code: _content!,
                  language: _language,
                  isDarkMode: isDark,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Path header bar showing the full file path.
class _PathHeader extends StatelessWidget {
  const _PathHeader({required this.path, required this.language});

  final String path;
  final String? language;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
              path,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: AppFontSize.sm,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (language != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              language!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: AppFontSize.xxs,
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Left column displaying line numbers.
class _LineNumbers extends StatelessWidget {
  const _LineNumbers({
    required this.lineCount,
    required this.fontSize,
    required this.lineHeight,
    required this.isDark,
  });
  final int lineCount;
  final double fontSize;
  final double lineHeight;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = isDark
        ? const Color(0xFF313244)
        : theme.colorScheme.outlineVariant;
    final numColor = isDark
        ? const Color(0xFF45475A)
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    final lineNumbers =
        List.generate(lineCount, (i) => '${i + 1}').join('\n');

    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.sm + AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: dividerColor)),
      ),
      child: Text(
        lineNumbers,
        textAlign: TextAlign.end,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: fontSize,
          color: numColor,
          height: lineHeight / fontSize,
        ),
      ),
    );
  }
}
