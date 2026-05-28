import 'dart:async';

import '../ml/session_ranker.dart';
import 'logger_service.dart' show logger;
import 'mmkv_storage.dart';

/// Service that manages smart features settings and Gemma initialization.
/// Follows the same pattern as AutoArchiveService for MMKV-backed settings.
class SmartFeaturesService {
  SmartFeaturesService._();

  static final SmartFeaturesService _instance = SmartFeaturesService._();

  static final SmartFeaturesService instance = SmartFeaturesService._instance;

  final _storage = MMKVStorage();

  Timer? _debounceTimer;

  static const _debounceDuration = Duration(milliseconds: 500);

  static const _keySmartFeaturesEnabled = 'smart-features-enabled';
  static const _keySemanticSearchEnabled = 'smart-features-semantic-search';
  static const _keyAutoTagsEnabled = 'smart-features-auto-tags';

  /// Whether smart features are enabled.
  bool get smartFeaturesEnabled =>
      _storage.getBool(_keySmartFeaturesEnabled) ?? false;

  /// Whether semantic search is enabled.
  bool get semanticSearchEnabled =>
      _storage.getBool(_keySemanticSearchEnabled) ?? false;

  /// Whether auto-tags are enabled.
  bool get autoTagsEnabled =>
      _storage.getBool(_keyAutoTagsEnabled) ?? false;

  /// Whether on-device smart features are active.
  ///
  /// Smart features (session ranking + auto-tags) run entirely on-device
  /// using local heuristics and require no downloaded model, so they are
  /// ready whenever the feature is enabled.
  bool get isReady => smartFeaturesEnabled;

  /// The session ranker instance. Null until [initialize] completes.
  SessionRanker? _sessionRanker;

  /// The session ranker instance. Throws if accessed before
  /// [initialize] completes — callers should check [_initialized].
  SessionRanker get sessionRanker =>
      _sessionRanker ??= SessionRanker(gemmaEnabled: false);

  bool _initialized = false;

  /// Initializes the service and Gemma model.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    _sessionRanker = SessionRanker(
      gemmaEnabled: smartFeaturesEnabled,
    );
    await _sessionRanker!.initialize();
    logger.info(
      'SmartFeaturesService: initialized, '
      'Gemma available=${_sessionRanker!.isAvailable}',
    );
  }

  /// Updates smart features enabled setting.
  Future<void> setSmartFeaturesEnabled(bool value) async {
    _storage.setBool(_keySmartFeaturesEnabled, value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _onSettingChanged();
    });
  }

  /// Updates semantic search enabled setting.
  Future<void> setSemanticSearchEnabled(bool value) async {
    _storage.setBool(_keySemanticSearchEnabled, value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _onSettingChanged();
    });
  }

  /// Updates auto-tags enabled setting.
  Future<void> setAutoTagsEnabled(bool value) async {
    _storage.setBool(_keyAutoTagsEnabled, value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _onSettingChanged();
    });
  }

  void _onSettingChanged() {
    if (smartFeaturesEnabled) {
      _sessionRanker = SessionRanker(gemmaEnabled: true);
      _sessionRanker!.initialize();
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _sessionRanker?.dispose();
  }
}
