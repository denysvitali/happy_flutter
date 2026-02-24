/// Web mermaid diagram renderer using HtmlElementView + iframe.
///
/// This file is selected on web platforms via the conditional import
/// in mermaid_renderer.dart. It uses dart:ui_web and package:web
/// (Dart 3.x / Flutter 3.38+) to embed an iframe that loads mermaid.js
/// from CDN.
///
/// Each diagram code gets a unique view type so that distinct diagrams
/// shown simultaneously each get their own iframe.
library;

import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Tracks which view types have already been registered so we never
/// call [ui_web.platformViewRegistry.registerViewFactory] twice for
/// the same key (repeated registration throws on web).
final Set<String> _registeredViewTypes = {};

/// Returns a CSS hex colour string for the given [color].
String _toHex(Color color) {
  final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${argb.substring(2)}';
}

/// Escapes HTML special characters so mermaid code can be safely
/// embedded inside an HTML attribute or element body.
String _escapeHtml(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

/// Builds the full srcdoc HTML string for the mermaid iframe.
String _buildSrcdoc(
  String code,
  String backgroundColor,
  String textColor,
  String errorColor,
) {
  final escaped = _escapeHtml(code);
  return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport"
    content="width=device-width,initial-scale=1,maximum-scale=1">
  <script
    src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js">
  </script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      padding: 16px;
      background-color: $backgroundColor;
      color: $textColor;
      font-family: -apple-system, BlinkMacSystemFont,
        'Segoe UI', Roboto, sans-serif;
      overflow-x: hidden;
    }
    .mermaid { text-align: center; width: 100%; }
    .mermaid svg { max-width: 100%; height: auto; }
    .error-msg {
      padding: 12px;
      background: rgba(239,68,68,0.1);
      border: 1px solid $errorColor;
      border-radius: 4px;
      color: $errorColor;
      font-family: monospace;
      font-size: 14px;
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="mermaid">$escaped</div>
  <script>
    (function () {
      mermaid.initialize({
        startOnLoad: false,
        theme: 'default',
        securityLevel: 'loose',
        logLevel: 'error'
      });
      mermaid.run({ nodes: ['.mermaid'] }).catch(function (err) {
        var el = document.querySelector('.mermaid');
        el.innerHTML =
          '<div class="error-msg">Mermaid diagram syntax error</div>';
        console.error('Mermaid error:', err);
      });
    })();
  </script>
</body>
</html>
''';
}

/// A widget that renders Mermaid diagrams on the web platform.
///
/// Uses [HtmlElementView] backed by an iframe with an inline srcdoc
/// so no cross-origin restrictions apply. Mermaid.js is loaded from
/// the jsDelivr CDN inside the sandboxed frame.
class MermaidBlockWidget extends StatefulWidget {
  const MermaidBlockWidget({required this.content, super.key});
  final String content;

  @override
  State<MermaidBlockWidget> createState() => _MermaidBlockWidgetState();
}

class _MermaidBlockWidgetState extends State<MermaidBlockWidget> {
  late String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'mermaid-diagram-${widget.content.hashCode}';
    _ensureRegistered(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-register if the theme changed and a new view type is needed.
    _ensureRegistered(context);
  }

  @override
  void didUpdateWidget(MermaidBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      _viewType = 'mermaid-diagram-${widget.content.hashCode}';
      _ensureRegistered(context);
    }
  }

  void _ensureRegistered(BuildContext ctx) {
    if (_registeredViewTypes.contains(_viewType)) return;
    _registeredViewTypes.add(_viewType);

    final theme = Theme.of(ctx);
    final bgColor = _toHex(theme.colorScheme.surfaceContainerHighest);
    final txtColor = _toHex(theme.colorScheme.onSurfaceVariant);
    final errColor = _toHex(theme.colorScheme.error);
    final srcdoc = _buildSrcdoc(
      widget.content,
      bgColor,
      txtColor,
      errColor,
    );

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final iframe = web.HTMLIFrameElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.border = 'none'
          ..setAttribute('srcdoc', srcdoc)
          ..setAttribute(
            'sandbox',
            'allow-scripts allow-same-origin',
          );
        return iframe;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox(
        height: 240,
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          child: _MermaidHtmlView(),
        ),
      ),
    );
  }
}

/// Internal stateless wrapper so the [HtmlElementView] key can be
/// reconstructed by the parent when content changes.
class _MermaidHtmlView extends StatelessWidget {
  const _MermaidHtmlView();

  @override
  Widget build(BuildContext context) {
    // Walk up to the MermaidBlockWidget to retrieve the view type.
    // We use a custom InheritedWidget would be cleaner, but since this
    // is a private class always parented by _MermaidBlockWidgetState
    // we can safely cast the ancestor's state.
    final state = context
        .findAncestorStateOfType<_MermaidBlockWidgetState>()!;
    return HtmlElementView(viewType: state._viewType);
  }
}
