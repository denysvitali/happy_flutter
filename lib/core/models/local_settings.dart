import 'package:freezed_annotation/freezed_annotation.dart';

part 'local_settings.freezed.dart';
part 'local_settings.g.dart';

/// Auto-archive settings for sessions.
@freezed
abstract class AutoArchiveSettings with _$AutoArchiveSettings {
  const factory AutoArchiveSettings({
    /// Archive sessions older than N days. Null = disabled.
    int? autoArchiveAfterDays,
    /// Archive sessions with no messages for N days. Null = disabled.
    int? autoArchiveIdleAfterDays,
    /// Whether to archive sessions when the app closes.
    @Default(false) bool autoArchiveOnAppClose,
  }) = _AutoArchiveSettings;

  factory AutoArchiveSettings.fromJson(Map<String, dynamic> json) =>
      _$AutoArchiveSettingsFromJson(json);
}

/// LocalSettings model
/// Device-specific settings that should NOT be synced across devices
@freezed
abstract class LocalSettings with _$LocalSettings {
  const factory LocalSettings({
    @Default(false) bool debugMode,
    @Default(false) bool devModeEnabled,
    @Default(false) bool commandPaletteEnabled,
    @Default('adaptive') String themePreference,
    @Default(false) bool markdownCopyV2,
    @Default(<String, String>{}) Map<String, String> acknowledgedCliVersions,
    AutoArchiveSettings? autoArchiveSettings,
  }) = _LocalSettings;

  const LocalSettings._();

  factory LocalSettings.fromJson(Map<String, dynamic> json) =>
      _$LocalSettingsFromJson(json);

  /// Default settings
  static const defaults = LocalSettings();

  /// Parse settings with fallback to defaults
  static LocalSettings parse(dynamic settings) {
    if (settings is Map<String, dynamic>) {
      return LocalSettings.fromJson(settings);
    }
    return LocalSettings.defaults;
  }
}
