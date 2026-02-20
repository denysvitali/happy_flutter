/// Mermaid diagram renderer — platform-adaptive.
///
/// Selects the correct back-end at compile time:
///   - Web: [mermaid_renderer_web.dart] — HtmlElementView + iframe
///   - Native: [mermaid_renderer_native.dart] — webview_flutter
///
/// Consumers always import this file; the platform-specific files must
/// never be imported directly from outside this directory.
library;

export 'mermaid_renderer_native.dart'
    if (dart.library.js_interop) 'mermaid_renderer_web.dart';
