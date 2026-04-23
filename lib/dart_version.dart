export 'dart_version_native.dart'
    if (dart.library.js_interop) 'dart_version_web.dart'
    if (dart.library.html) 'dart_version_web.dart';
