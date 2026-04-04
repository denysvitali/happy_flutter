// Conditional export: on web, use the SharedPreferences-backed
// implementation; on native (dart:io available), use MMKV.
export 'server_config_storage_web.dart'
    if (dart.library.io) 'server_config_storage_native.dart';
