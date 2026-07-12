import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/services/logger_service.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/theme/code_viewer_theme.dart';
import 'package:happy_flutter/core/utils/clipboard_utils.dart';

import '../../core/components/app_empty_state.dart';
import '../../core/providers/app_providers.dart';
import 'markdown/markdown_view.dart';
import 'syntax_highlighter.dart';

/// Whether [extension] (without dot) is a markdown file.
bool _isMarkdown(String extension) =>
    extension == 'md' || extension == 'markdown' || extension == 'mdx';

/// Raster formats Flutter can decode natively via [Image.memory].
const Set<String> _imageExtensions = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
};

/// Whether [extension] (without dot) is a renderable image file.
bool _isImage(String extension) => _imageExtensions.contains(extension);

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
class SessionFileViewerScreen extends ConsumerStatefulWidget {
  /// Creates a [SessionFileViewerScreen].
  const SessionFileViewerScreen({
    required this.path,
    required this.sessionId,
    this.content,
    this.embedded = false,
    this.onClose,
    super.key,
  });

  /// The full file path to display.
  final String path;

  /// The session whose machine should be used to fetch the file.
  final String sessionId;

  /// Optional pre-loaded file content.
  final String? content;

  /// When true, render as a pane inside a tablet master-detail layout.
  /// Skips the outer [Scaffold]/[AppBar] and uses a thin in-pane header.
  final bool embedded;

  /// Called when the in-pane close button is tapped (embedded only).
  final VoidCallback? onClose;

  @override
  ConsumerState<SessionFileViewerScreen> createState() =>
      _SessionFileViewerScreenState();
}

class _SessionFileViewerScreenState
    extends ConsumerState<SessionFileViewerScreen> {
  String? _content;
  Uint8List? _imageBytes;
  int _lineCount = 0;
  String? _error;
  bool _loading = false;
  bool _copied = false;

  /// Current view mode (only meaningful for markdown files).
  _ViewMode _viewMode = _ViewMode.preview;

  /// Vertical scroll controller shared between the line-number gutter and the
  /// code pane so both stay vertically aligned.
  late final ScrollController _vController;

  /// Horizontal scroll controller for the code pane only (line numbers are
  /// pinned and do not scroll horizontally).
  late final ScrollController _hController;

  @override
  void initState() {
    super.initState();
    _vController = ScrollController();
    _hController = ScrollController();
    if (widget.content != null && widget.content!.isNotEmpty) {
      if (_isImageFile) {
        _imageBytes = _tryBase64DecodeBytes(widget.content!);
      }
      if (_imageBytes == null) {
        _content = widget.content;
        _lineCount = '\n'.allMatches(widget.content!).length + 1;
      }
    } else {
      _fetchFile();
    }
  }

  @override
  void dispose() {
    _vController.dispose();
    _hController.dispose();
    super.dispose();
  }

  Future<void> _fetchFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = ref.read(sessionsNotifierProvider)[widget.sessionId];
      final machineId = session?.metadata?.machineId;
      if (machineId == null || machineId.isEmpty) {
        setState(() {
          _error = 'No machine associated with this session';
          _loading = false;
        });
        return;
      }

      final response = await ref
          .read(machinesNotifierProvider.notifier)
          .readFile(
            machineId: machineId,
            filePath: widget.path,
          );

      if (!mounted) return;

      if (response.success) {
        // The daemon returns base64-encoded content.
        if (_isImageFile) {
          final bytes = _tryBase64DecodeBytes(response.content);
          if (bytes != null) {
            setState(() {
              _imageBytes = bytes;
              _loading = false;
            });
            return;
          }
        }
        final decoded = _tryBase64Decode(response.content);
        setState(() {
          _content = decoded;
          _lineCount = '\n'.allMatches(decoded).length + 1;
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

  /// Attempts base64 decoding to raw bytes; returns null when [input] is
  /// not valid base64 (so callers can fall back to the text path).
  static Uint8List? _tryBase64DecodeBytes(String input) {
    try {
      return base64Decode(input.trim());
    } catch (_) {
      return null;
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
    final segments = widget.path.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isNotEmpty ? segments.last : widget.path;
  }

  /// The detected language for syntax highlighting (null if unknown).
  String? get _language {
    final ext = _extensionOf(widget.path);
    if (ext.isEmpty) return null;
    return detectLanguage(ext);
  }

  bool get _isMd => _isMarkdown(_extensionOf(widget.path));

  bool get _isImageFile => _isImage(_extensionOf(widget.path));

  Future<void> _copyToClipboard() async {
    if (_content == null) return;
    await setClipboardTextSafely(_content!);
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final actions = <Widget>[
      // Copy button
      if (_content != null)
        IconButton(
          icon: Icon(
            _copied ? Icons.check_rounded : Icons.content_copy_rounded,
            size: 20,
          ),
          // TODO(i18n): copy tooltip not yet localized
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
          // TODO(i18n): view-mode tooltip not yet localized
          tooltip: _viewMode == _ViewMode.preview
              ? 'View source'
              : 'View preview',
          onPressed: () => setState(() {
            _viewMode = _viewMode == _ViewMode.preview
                ? _ViewMode.code
                : _ViewMode.preview;
          }),
        ),
    ];

    final body = Column(
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
        Expanded(child: _buildContent(theme)),
      ],
    );

    if (!widget.embedded) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_fileName, overflow: TextOverflow.ellipsis),
          actions: actions,
        ),
        body: body,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FileViewerEmbeddedHeader(
          fileName: _fileName,
          actions: actions,
          onClose: widget.onClose,
        ),
        Expanded(child: body),
      ],
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

    // Image files render as a zoomable picture instead of raw bytes.
    if (_imageBytes != null) {
      return _ImageView(bytes: _imageBytes!);
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

    // Syntax-highlighted code view.
    //
    // Line numbers live in their own vertical scroll view on the left and share
    // [_vController] with the code pane so they scroll vertically in sync. The
    // code pane is wrapped in a horizontal scroll view, so long lines scroll
    // sideways without carrying the gutter with them.
    final isDark = theme.brightness == Brightness.dark;
    const fontSize = AppFontSize.md;
    const lineHeight = fontSize * 1.5;
    return Scrollbar(
      controller: _vController,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            controller: _vController,
            primary: false,
            physics: const ClampingScrollPhysics(),
            scrollDirection: Axis.vertical,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: _LineNumbers(
              lineCount: _lineCount,
              fontSize: fontSize,
              lineHeight: lineHeight,
              isDark: isDark,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _hController,
              primary: false,
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                controller: _vController,
                primary: false,
                physics: const ClampingScrollPhysics(),
                scrollDirection: Axis.vertical,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Padding(
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zoomable image pane for image files (PNG, JPEG, GIF, WebP, BMP).
class _ImageView extends StatelessWidget {
  const _ImageView({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: 8,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return const AppEmptyState(
                icon: Icons.broken_image_outlined,
                title: 'Could not display image',
                subtitle: 'The file is not a valid or supported image.',
              );
            },
          ),
        ),
      ),
    );
  }
}

/// In-pane header used when the viewer is embedded inside a tablet
/// master-detail scaffold. Shows the file name, the same action buttons
/// as the AppBar, and a close button.
class _FileViewerEmbeddedHeader extends StatelessWidget {
  const _FileViewerEmbeddedHeader({
    required this.fileName,
    required this.actions,
    this.onClose,
  });

  final String fileName;
  final List<Widget> actions;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: AppBorder.hairline,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              fileName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
          if (onClose != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              // TODO(i18n): close tooltip not yet localized
              tooltip: 'Close',
              onPressed: onClose,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
        ],
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
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
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
    // Use the CodeViewerTheme extension for code-block chrome (light
    // and dark). The previous hardcoded Catppuccin Mocha hexes were
    // correct for dark mode but the light branch fell back to
    // cs.outlineVariant / onSurfaceVariant@0.5 — using the
    // extension unifies the palette with the rest of the code-block
    // chrome (code_block_widget, inline theme picker).
    final codeViewer = theme.extension<CodeViewerTheme>() ??
        (theme.brightness == Brightness.dark
            ? CodeViewerTheme.dark
            : CodeViewerTheme.light);
    final dividerColor = codeViewer.divider;
    final numColor = codeViewer.lineNumberText;

    final lineNumbers = List.generate(lineCount, (i) => '${i + 1}').join('\n');

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
