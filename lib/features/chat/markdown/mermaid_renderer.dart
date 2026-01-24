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

  @override
  void initState() {
    super.initState();
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
    final backgroundColor = _colorToHex(theme.colorScheme.surfaceVariant);
    final textColor = _colorToHex(theme.colorScheme.onSurfaceVariant);

    final html = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"></script>
    <style>
        body {
            margin: 0;
            padding: 16px;
            background-color: $backgroundColor;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            color: $textColor;
        }
        #mermaid-container {
            display: flex;
            justify-content: center;
            align-items: center;
            width: 100%;
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
            background-color: ${_colorToHex(theme.colorScheme.errorContainer ?? Colors.red.shade100)};
            border-radius: 4px;
            color: ${_colorToHex(theme.colorScheme.onErrorContainer ?? Colors.red)};
        }
    </style>
</head>
<body>
    <div id="mermaid-container" class="mermaid">
        ${widget.content}
    </div>
    <script>
        mermaid.initialize({
            startOnLoad: true,
            theme: 'default',
            securityLevel: 'loose'
        });
        mermaid.run({
            nodes: ['.mermaid']
        }).catch(function(error) {
            var container = document.getElementById('mermaid-container');
            container.innerHTML = '<div class="error-message">Syntax error in diagram</div>';
            console.error('Mermaid error:', error);
        });
    </script>
</body>
</html>
''';

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
            child: WebViewWidget(
              controller: WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..setBackgroundColor(theme.colorScheme.surfaceVariant)
                ..setNavigationDelegate(
                  NavigationDelegate(
                    onPageFinished: (_) {
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    },
                  ),
                )
                ..loadHtmlString(html),
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
          Text(
            'Mermaid diagram syntax error',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: theme.colorScheme.error,
            ),
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
