/// Mermaid diagram renderer using WebView.
///
/// Renders mermaid diagrams by loading them in an embedded WebView
/// with the mermaid.js library. Supports both mobile and web platforms.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A widget that renders Mermaid diagrams.
///
/// Uses WebView on all platforms for consistent rendering.
/// The mermaid.js library is loaded from CDN.
class MermaidBlockWidget extends StatefulWidget {
  final String content;

  const MermaidBlockWidget({super.key, required this.content});

  @override
  State<MermaidBlockWidget> createState() => _MermaidBlockWidgetState();
}

class _MermaidBlockWidgetState extends State<MermaidBlockWidget> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (error) {
            if (mounted && !_hasError) {
              setState(() {
                _hasError = true;
                _errorMessage = error.description;
                _isLoading = false;
              });
            }
          },
        ),
      );
  }

  @override
  void didUpdateWidget(MermaidBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
      _loadMermaid();
    }
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  void _loadMermaid() {
    if (_controller == null) return;

    final theme = Theme.of(context);
    final backgroundColor = _colorToHex(theme.colorScheme.surfaceVariant);
    final textColor = _colorToHex(theme.colorScheme.onSurfaceVariant);
    final errorColor = _colorToHex(theme.colorScheme.error);

    final html = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            padding: 16px;
            background-color: $backgroundColor;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            color: $textColor;
            overflow-x: hidden;
        }
        #mermaid-container {
            display: flex;
            justify-content: center;
            align-items: center;
            width: 100%;
            min-height: 100px;
        }
        .mermaid {
            text-align: center;
            width: 100%;
        }
        .mermaid svg {
            max-width: 100%;
            height: auto;
        }
        .error-message {
            padding: 12px;
            background-color: rgba(239, 68, 68, 0.1);
            border: 1px solid $errorColor;
            border-radius: 4px;
            color: $errorColor;
            text-align: center;
            font-family: monospace;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div id="mermaid-container" class="mermaid">
        ${_escapeHtml(widget.content)}
    </div>
    <script>
        (function() {
            mermaid.initialize({
                startOnLoad: false,
                theme: 'default',
                securityLevel: 'loose',
                logLevel: 'error'
            });

            mermaid.run({
                nodes: ['.mermaid']
            }).then(function(result) {
                // Success - diagram rendered
                if (window.FlutterChannel) {
                    window.FlutterChannel.postMessage(JSON.stringify({type: 'success'}));
                }
            }).catch(function(error) {
                // Error - show error message
                console.error('Mermaid error:', error);
                var container = document.getElementById('mermaid-container');
                container.innerHTML = '<div class="error-message">Mermaid diagram syntax error</div>';
                if (window.FlutterChannel) {
                    window.FlutterChannel.postMessage(JSON.stringify({
                        type: 'error',
                        message: error.message || 'Syntax error'
                    }));
                }
            });
        })();
    </script>
</body>
</html>
''';

    _controller!.loadHtmlString(html);
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_hasError) {
      return _buildErrorView(theme);
    }

    return _buildWebView(theme);
  }

  Widget _buildWebView(ThemeData theme) {
    if (_controller == null) {
      return const SizedBox.shrink();
    }

    // Trigger the load on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isLoading) {
        _loadMermaid();
      }
    });

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoading)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          SizedBox(
            height: _isLoading ? 0 : null,
            child: SizedBox(
              height: _isLoading ? 0 : 200,
              child: WebViewWidget(controller: _controller!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Mermaid diagram syntax error',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              widget.content,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.4,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _colorToHex(Color color) {
    final hex = '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
    return hex;
  }
}
