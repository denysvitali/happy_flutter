// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AutoArchiveSettings _$AutoArchiveSettingsFromJson(Map<String, dynamic> json) =>
    _AutoArchiveSettings(
      autoArchiveAfterDays: (json['autoArchiveAfterDays'] as num?)?.toInt(),
      autoArchiveIdleAfterDays: (json['autoArchiveIdleAfterDays'] as num?)
          ?.toInt(),
      autoArchiveOnAppClose: json['autoArchiveOnAppClose'] as bool? ?? false,
    );

Map<String, dynamic> _$AutoArchiveSettingsToJson(
  _AutoArchiveSettings instance,
) => <String, dynamic>{
  'autoArchiveAfterDays': instance.autoArchiveAfterDays,
  'autoArchiveIdleAfterDays': instance.autoArchiveIdleAfterDays,
  'autoArchiveOnAppClose': instance.autoArchiveOnAppClose,
};

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
      autoArchiveSettings: json['autoArchiveSettings'] == null
          ? null
          : AutoArchiveSettings.fromJson(
              json['autoArchiveSettings'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$LocalSettingsToJson(_LocalSettings instance) =>
    <String, dynamic>{
      'debugMode': instance.debugMode,
      'devModeEnabled': instance.devModeEnabled,
      'commandPaletteEnabled': instance.commandPaletteEnabled,
      'themePreference': instance.themePreference,
      'markdownCopyV2': instance.markdownCopyV2,
      'acknowledgedCliVersions': instance.acknowledgedCliVersions,
      'autoArchiveSettings': instance.autoArchiveSettings?.toJson(),
    };
