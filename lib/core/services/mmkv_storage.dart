// Conditional export: on web, use the SharedPreferences-backed
// implementation; on native (dart:io available), use MMKV.
export 'mmkv_storage_web.dart'
    if (dart.library.io) 'mmkv_storage_native.dart';
