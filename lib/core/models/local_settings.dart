/// LocalSettings model
/// Device-specific settings that should NOT be synced across devices
class LocalSettings {
  final bool debugMode;
  final bool devModeEnabled;
  final bool commandPaletteEnabled;
  final String themePreference; // 'light', 'dark', or 'adaptive'
  final bool markdownCopyV2;
  final Map<String, String> acknowledgedCliVersions;

  const LocalSettings({
    this.debugMode = false,
    this.devModeEnabled = false,
    this.commandPaletteEnabled = false,
    this.themePreference = 'adaptive',
    this.markdownCopyV2 = false,
    this.acknowledgedCliVersions = const {},
  });

  LocalSettings copyWith({
    bool? debugMode,
    bool? devModeEnabled,
    bool? commandPaletteEnabled,
    String? themePreference,
    bool? markdownCopyV2,
    Map<String, String>? acknowledgedCliVersions,
  }) {
    return LocalSettings(
      debugMode: debugMode ?? this.debugMode,
      devModeEnabled: devModeEnabled ?? this.devModeEnabled,
      commandPaletteEnabled: commandPaletteEnabled ?? this.commandPaletteEnabled,
      themePreference: themePreference ?? this.themePreference,
      markdownCopyV2: markdownCopyV2 ?? this.markdownCopyV2,
      acknowledgedCliVersions:
          acknowledgedCliVersions ?? this.acknowledgedCliVersions,
    );
  }

  factory LocalSettings.fromJson(Map<String, dynamic> json) {
    return LocalSettings(
      debugMode: json['debugMode'] as bool? ?? false,
      devModeEnabled: json['devModeEnabled'] as bool? ?? false,
      commandPaletteEnabled: json['commandPaletteEnabled'] as bool? ?? false,
      themePreference: json['themePreference'] as String? ?? 'adaptive',
      markdownCopyV2: json['markdownCopyV2'] as bool? ?? false,
      acknowledgedCliVersions:
          (json['acknowledgedCliVersions'] as Map<String, dynamic>?)?.map(
                (k, v) => MapEntry(k, v as String),
              ) ??
              {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'debugMode': debugMode,
      'devModeEnabled': devModeEnabled,
      'commandPaletteEnabled': commandPaletteEnabled,
      'themePreference': themePreference,
      'markdownCopyV2': markdownCopyV2,
      'acknowledgedCliVersions': acknowledgedCliVersions,
    };
  }

  /// Default settings
  static const defaults = LocalSettings();

  /// Parse settings with fallback to defaults
  static LocalSettings parse(dynamic settings) {
    if (settings is Map<String, dynamic>) {
      return LocalSettings.fromJson(settings);
    }
    return const LocalSettings();
  }
}
