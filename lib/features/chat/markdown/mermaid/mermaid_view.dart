/// Native Mermaid diagram rendering for chat markdown.
///
/// ```mermaid fenced blocks are parsed and painted in Dart — no WebView, no
/// network, no third-party renderer — so diagrams work on every platform and
/// never leave the device. Unsupported or malformed sources fall back to the
/// regular code block with a short notice.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/theme/app_color_scheme.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../code_block_widget.dart';
import 'mermaid_layout.dart';
import 'mermaid_model.dart';
import 'mermaid_parser.dart';
import 'mermaid_scene.dart';

/// Whether a fenced code block language selects the Mermaid renderer.
bool isMermaidLanguage(String? language) =>
    language != null && language.trim().toLowerCase() == 'mermaid';

/// Inline scale floor: below this, wide diagrams scroll sideways instead.
const double _minInlineScale = 0.55;

/// Tallest inline diagram; taller ones are clipped (full screen shows all).
const double _maxInlineHeight = 560;

/// Renders a Mermaid [source] as a diagram card.
class MermaidDiagramView extends StatefulWidget {
  /// Creates a diagram view.
  const MermaidDiagramView({required this.source, super.key});

  /// Mermaid source (the fenced block body).
  final String source;

  @override
  State<MermaidDiagramView> createState() => _MermaidDiagramViewState();
}

class _MermaidDiagramViewState extends State<MermaidDiagramView> {
  MermaidDiagram? _diagram;
  MermaidParseException? _error;
  MermaidScene? _scene;
  Object? _sceneKey;
  bool _sceneFailed = false;
  bool _showSource = false;

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(MermaidDiagramView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _parse();
    }
  }

  @override
  void dispose() {
    _scene?.dispose();
    super.dispose();
  }

  void _parse() {
    _scene?.dispose();
    _scene = null;
    _sceneKey = null;
    _sceneFailed = false;
    try {
      _diagram = parseMermaid(widget.source);
      _error = null;
    } on MermaidParseException catch (error) {
      _diagram = null;
      _error = error;
    } catch (error, stackTrace) {
      logger.warning('Mermaid parse failed', error, stackTrace);
      _diagram = null;
      _error = const MermaidParseException('Parse failed');
    }
  }

  MermaidScene? _sceneFor(BuildContext context) {
    final diagram = _diagram;
    if (diagram == null || _sceneFailed) return null;
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final key = (theme.brightness, theme.colorScheme, scaler);
    if (_scene != null && _sceneKey == key) return _scene;
    try {
      final scene = buildMermaidScene(diagram, MermaidTheme.of(theme, scaler));
      if (!scene.size.isFinite || scene.size.isEmpty) {
        scene.dispose();
        _sceneFailed = true;
        return null;
      }
      _scene?.dispose();
      _scene = scene;
      _sceneKey = key;
      return scene;
    } catch (error, stackTrace) {
      logger.warning('Mermaid layout failed', error, stackTrace);
      _sceneFailed = true;
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scene = _sceneFor(context);
    if (scene == null) {
      return _MermaidFallback(
        source: widget.source,
        unsupported: _error?.unsupported ?? false,
      );
    }
    final theme = Theme.of(context);
    final colors = theme.extension<AppColorScheme>() ?? AppColorScheme.dark();
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: colors.glassBorder,
          width: AppBorder.hairline,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(
            showSource: _showSource,
            onToggleSource: () => setState(() => _showSource = !_showSource),
            onFullScreen: () => _openFullScreen(context),
          ),
          if (_showSource)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: CodeBlockWidget(code: widget.source, language: 'mermaid'),
            )
          else
            Semantics(
              image: true,
              label: l10n.mermaidSemanticsLabel(_semanticsText(scene)),
              child: GestureDetector(
                onTap: () => _openFullScreen(context),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    0,
                    AppSpacing.sm,
                    AppSpacing.sm,
                  ),
                  child: _InlineDiagram(scene: scene),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _semanticsText(MermaidScene scene) {
    final text = scene.labels.map((l) => l.replaceAll('\n', ' ')).join(', ');
    return text.length > 600 ? '${text.substring(0, 600)}…' : text;
  }

  void _openFullScreen(BuildContext context) {
    final diagram = _diagram;
    if (diagram == null) return;
    showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (dialogContext) => Scaffold(
        appBar: AppBar(
          title: Text(dialogContext.l10n.mermaidDiagramTitle),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: MaterialLocalizations.of(dialogContext).closeButtonTooltip,
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ),
        backgroundColor: Theme.of(
          dialogContext,
        ).colorScheme.surfaceContainerHighest,
        body: SafeArea(child: _FullScreenDiagram(diagram: diagram)),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.showSource,
    required this.onToggleSource,
    required this.onFullScreen,
  });

  final bool showSource;
  final VoidCallback onToggleSource;
  final VoidCallback onFullScreen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.account_tree_outlined, size: 16, color: muted),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              l10n.mermaidDiagramTitle,
              style: theme.textTheme.labelMedium?.copyWith(color: muted),
            ),
          ),
          IconButton(
            icon: Icon(
              showSource ? Icons.schema_outlined : Icons.code_rounded,
              size: 18,
            ),
            tooltip: showSource
                ? l10n.mermaidShowDiagram
                : l10n.mermaidShowSource,
            onPressed: onToggleSource,
          ),
          IconButton(
            icon: const Icon(Icons.open_in_full_rounded, size: 18),
            tooltip: l10n.mermaidOpenFullScreen,
            onPressed: onFullScreen,
          ),
        ],
      ),
    );
  }
}

/// Fits the diagram to the bubble width, scrolling sideways when it would
/// otherwise shrink below [_minInlineScale].
class _InlineDiagram extends StatelessWidget {
  const _InlineDiagram({required this.scene});

  final MermaidScene scene;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : scene.size.width;
        var scale = math.min(1.0, available / scene.size.width);
        scale = math.min(scale, _maxInlineHeight / scene.size.height);
        scale = math.max(scale, _minInlineScale);
        final width = scene.size.width * scale;
        final height = scene.size.height * scale;
        Widget diagram = RepaintBoundary(
          child: CustomPaint(
            size: Size(width, height),
            painter: MermaidScenePainter(scene),
          ),
        );
        if (height > _maxInlineHeight) {
          diagram = ClipRect(
            child: SizedBox(
              width: width,
              height: _maxInlineHeight,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: height,
                maxHeight: height,
                child: diagram,
              ),
            ),
          );
        }
        if (width > available) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: diagram,
          );
        }
        return Center(child: diagram);
      },
    );
  }
}

/// Zoomable viewer. It lays out its own scene: the inline card can be
/// recycled (and dispose its text layouts) while the dialog is still open.
class _FullScreenDiagram extends StatefulWidget {
  const _FullScreenDiagram({required this.diagram});

  final MermaidDiagram diagram;

  @override
  State<_FullScreenDiagram> createState() => _FullScreenDiagramState();
}

class _FullScreenDiagramState extends State<_FullScreenDiagram> {
  final _controller = TransformationController();
  Size? _fittedFor;
  MermaidScene? _scene;
  Object? _sceneKey;

  @override
  void dispose() {
    _controller.dispose();
    _scene?.dispose();
    super.dispose();
  }

  MermaidScene _sceneFor(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final key = (theme.brightness, theme.colorScheme, scaler);
    if (_scene == null || _sceneKey != key) {
      _scene?.dispose();
      _scene = buildMermaidScene(
        widget.diagram,
        MermaidTheme.of(theme, scaler),
      );
      _sceneKey = key;
      _fittedFor = null;
    }
    return _scene!;
  }

  @override
  Widget build(BuildContext context) {
    final scene = _sceneFor(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.biggest;
        final size = scene.size;
        if (_fittedFor != viewport) {
          _fittedFor = viewport;
          final fit = math.min(
            2.0,
            math.min(
              viewport.width / size.width,
              viewport.height / size.height,
            ),
          );
          final dx = (viewport.width - size.width * fit) / 2;
          final dy = (viewport.height - size.height * fit) / 2;
          _controller.value = Matrix4.identity()
            ..translateByDouble(dx, math.max(dy, 0), 0, 1)
            ..scaleByDouble(fit, fit, 1, 1);
        }
        return InteractiveViewer(
          transformationController: _controller,
          constrained: false,
          minScale: 0.1,
          maxScale: 8,
          boundaryMargin: EdgeInsets.all(
            math.max(viewport.width, viewport.height),
          ),
          child: CustomPaint(size: size, painter: MermaidScenePainter(scene)),
        );
      },
    );
  }
}

class _MermaidFallback extends StatelessWidget {
  const _MermaidFallback({required this.source, required this.unsupported});

  final String source;
  final bool unsupported;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  unsupported
                      ? l10n.mermaidUnsupported
                      : l10n.mermaidRenderFailed,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        CodeBlockWidget(code: source, language: 'mermaid'),
      ],
    );
  }
}
