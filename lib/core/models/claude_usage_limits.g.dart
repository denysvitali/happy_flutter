// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_usage_limits.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClaudeUsageWindow _$ClaudeUsageWindowFromJson(Map<String, dynamic> json) =>
    _ClaudeUsageWindow(
      utilization: json['utilization'] == null
          ? 0.0
          : _utilizationFromJson(json['utilization']),
      resetsAt: json['resets_at'] as String?,
    );

Map<String, dynamic> _$ClaudeUsageWindowToJson(_ClaudeUsageWindow instance) =>
    <String, dynamic>{
      'utilization': instance.utilization,
      'resets_at': instance.resetsAt,
    };

_ClaudeExtraUsage _$ClaudeExtraUsageFromJson(Map<String, dynamic> json) =>
    _ClaudeExtraUsage(
      isEnabled: json['is_enabled'] as bool? ?? false,
      monthlyLimit: _optionalDoubleFromJson(json['monthly_limit']),
      usedCredits: _optionalDoubleFromJson(json['used_credits']),
      utilization: _optionalDoubleFromJson(json['utilization']),
    );

Map<String, dynamic> _$ClaudeExtraUsageToJson(_ClaudeExtraUsage instance) =>
    <String, dynamic>{
      'is_enabled': instance.isEnabled,
      'monthly_limit': instance.monthlyLimit,
      'used_credits': instance.usedCredits,
      'utilization': instance.utilization,
    };

_ClaudeUsageLimits _$ClaudeUsageLimitsFromJson(Map<String, dynamic> json) =>
    _ClaudeUsageLimits(
      fiveHour: _windowOrNull(json['five_hour']),
      sevenDay: _windowOrNull(json['seven_day']),
      sevenDaySonnet: _windowOrNull(json['seven_day_sonnet']),
      sevenDayOpus: _windowOrNull(json['seven_day_opus']),
      sevenDayOauthApps: _windowOrNull(json['seven_day_oauth_apps']),
      sevenDayCowork: _windowOrNull(json['seven_day_cowork']),
      iguanaNecktie: _windowOrNull(json['iguana_necktie']),
      extraUsage: _extraUsageFromJson(json['extra_usage']),
    );

Map<String, dynamic> _$ClaudeUsageLimitsToJson(_ClaudeUsageLimits instance) =>
    <String, dynamic>{
      'five_hour': instance.fiveHour?.toJson(),
      'seven_day': instance.sevenDay?.toJson(),
      'seven_day_sonnet': instance.sevenDaySonnet?.toJson(),
      'seven_day_opus': instance.sevenDayOpus?.toJson(),
      'seven_day_oauth_apps': instance.sevenDayOauthApps?.toJson(),
      'seven_day_cowork': instance.sevenDayCowork?.toJson(),
      'iguana_necktie': instance.iguanaNecktie?.toJson(),
      'extra_usage': instance.extraUsage?.toJson(),
    };
