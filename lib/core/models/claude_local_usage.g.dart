// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'claude_local_usage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ClaudeLongestSession _$ClaudeLongestSessionFromJson(
  Map<String, dynamic> json,
) => _ClaudeLongestSession(
  date: json['date'] as String,
  messageCount: (json['messageCount'] as num).toInt(),
);

Map<String, dynamic> _$ClaudeLongestSessionToJson(
  _ClaudeLongestSession instance,
) => <String, dynamic>{
  'date': instance.date,
  'messageCount': instance.messageCount,
};

_ClaudeDailyModelTokens _$ClaudeDailyModelTokensFromJson(
  Map<String, dynamic> json,
) => _ClaudeDailyModelTokens(
  date: json['date'] as String,
  tokensByModel:
      (json['tokensByModel'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ) ??
      const <String, int>{},
);

Map<String, dynamic> _$ClaudeDailyModelTokensToJson(
  _ClaudeDailyModelTokens instance,
) => <String, dynamic>{
  'date': instance.date,
  'tokensByModel': instance.tokensByModel,
};

_ClaudeLocalUsage _$ClaudeLocalUsageFromJson(Map<String, dynamic> json) =>
    _ClaudeLocalUsage(
      version: (json['version'] as num?)?.toInt() ?? 0,
      lastComputedDate: json['lastComputedDate'] as String?,
      totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
      totalMessages: (json['totalMessages'] as num?)?.toInt() ?? 0,
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      totalToolCalls: (json['totalToolCalls'] as num?)?.toInt() ?? 0,
      tokensByModel:
          (json['tokensByModel'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const <String, int>{},
      longestSession: json['longestSession'] == null
          ? null
          : ClaudeLongestSession.fromJson(
              json['longestSession'] as Map<String, dynamic>,
            ),
      dailyModelTokens:
          (json['dailyModelTokens'] as List<dynamic>?)
              ?.map(
                (e) =>
                    ClaudeDailyModelTokens.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const <ClaudeDailyModelTokens>[],
    );

Map<String, dynamic> _$ClaudeLocalUsageToJson(
  _ClaudeLocalUsage instance,
) => <String, dynamic>{
  'version': instance.version,
  'lastComputedDate': instance.lastComputedDate,
  'totalTokens': instance.totalTokens,
  'totalMessages': instance.totalMessages,
  'totalSessions': instance.totalSessions,
  'totalToolCalls': instance.totalToolCalls,
  'tokensByModel': instance.tokensByModel,
  'longestSession': instance.longestSession?.toJson(),
  'dailyModelTokens': instance.dailyModelTokens.map((e) => e.toJson()).toList(),
};
