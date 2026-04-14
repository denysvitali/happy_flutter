// Conditional export: on web, use IndexedDB-backed sessions cache storage;
// on native (dart:io available), use MMKV via MMKVStorage.
//
// This file MUST NOT import dart:io directly. Platform detection is done at
// the conditional-export level.
export 'sessions_cache_storage_web.dart'
    if (dart.library.io) 'sessions_cache_storage_native.dart';
