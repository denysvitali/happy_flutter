// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LocalSettings _$LocalSettingsFromJson(Map<String, dynamic> json) =>
    _LocalSettings(
      debugMode: json['debugMode'] as bool? ?? false,
      devModeEnabled: json['devModeEnabled'] as bool? ?? false,
      commandPaletteEnabled: json['commandPaletteEnabled'] as bool? ?? false,
      themePreference: json['themePreference'] as String? ?? 'adaptive',
      markdownCopyV2: json['markdownCopyV2'] as bool? ?? false,
      acknowledgedCliVersions:
          (json['acknowledgedCliVersions'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const <String, String>{},
    );

Map<String, dynamic> _$LocalSettingsToJson(_LocalSettings instance) =>
    <String, dynamic>{
      'debugMode': instance.debugMode,
      'devModeEnabled': instance.devModeEnabled,
      'commandPaletteEnabled': instance.commandPaletteEnabled,
      'themePreference': instance.themePreference,
      'markdownCopyV2': instance.markdownCopyV2,
      'acknowledgedCliVersions': instance.acknowledgedCliVersions,
    };
