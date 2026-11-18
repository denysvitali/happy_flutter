/// Clipboard images for the composer, per platform.
///
/// * Desktop (Linux, macOS, Windows): the composer overrides Ctrl/Cmd+V and
///   calls [readClipboardImage] when the clipboard holds no text.
/// * Web: the browser owns Ctrl+V, so [listenForPastedImages] reads image
///   files from the DOM `paste` event (no clipboard permission prompt).
/// * Android: keyboards insert images through the text field's
///   `contentInsertionConfiguration`; nothing here applies.
library;

export 'clipboard_image_source_io.dart'
    if (dart.library.js_interop) 'clipboard_image_source_web.dart';
