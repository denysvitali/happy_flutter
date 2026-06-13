// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_usage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_KimiCredentials _$KimiCredentialsFromJson(Map<String, dynamic> json) =>
    _KimiCredentials(
      apiKey: json['apiKey'] as String,
      baseUrl: json['baseUrl'] as String? ?? kimiDefaultBaseUrl,
      accountName: json['accountName'] as String?,
    );

Map<String, dynamic> _$KimiCredentialsToJson(_KimiCredentials instance) =>
    <String, dynamic>{
      'apiKey': instance.apiKey,
      'baseUrl': instance.baseUrl,
      'accountName': instance.accountName,
    };

_MiniMaxCredentials _$MiniMaxCredentialsFromJson(Map<String, dynamic> json) =>
    _MiniMaxCredentials(
      cookie: json['cookie'] as String,
      groupId: json['groupId'] as String,
      accountName: json['accountName'] as String?,
    );

Map<String, dynamic> _$MiniMaxCredentialsToJson(_MiniMaxCredentials instance) =>
    <String, dynamic>{
      'cookie': instance.cookie,
      'groupId': instance.groupId,
      'accountName': instance.accountName,
    };

_ProviderCredentialsKimi _$ProviderCredentialsKimiFromJson(
  Map<String, dynamic> json,
) => _ProviderCredentialsKimi(
  KimiCredentials.fromJson(json['credentials'] as Map<String, dynamic>),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$ProviderCredentialsKimiToJson(
  _ProviderCredentialsKimi instance,
) => <String, dynamic>{
  'credentials': instance.credentials.toJson(),
  'runtimeType': instance.$type,
};

_ProviderCredentialsMiniMax _$ProviderCredentialsMiniMaxFromJson(
  Map<String, dynamic> json,
) => _ProviderCredentialsMiniMax(
  MiniMaxCredentials.fromJson(json['credentials'] as Map<String, dynamic>),
  $type: json['runtimeType'] as String?,
);

Map<String, dynamic> _$ProviderCredentialsMiniMaxToJson(
  _ProviderCredentialsMiniMax instance,
) => <String, dynamic>{
  'credentials': instance.credentials.toJson(),
  'runtimeType': instance.$type,
};

_ProviderAccount _$ProviderAccountFromJson(Map<String, dynamic> json) =>
    _ProviderAccount(
      id: json['id'] as String,
      name: json['name'] as String?,
      type: $enumDecode(_$ProviderUsageTypeEnumMap, json['type']),
      credentials: ProviderCredentials.fromJson(
        json['credentials'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$ProviderAccountToJson(_ProviderAccount instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'type': _$ProviderUsageTypeEnumMap[instance.type]!,
      'credentials': instance.credentials.toJson(),
    };

const _$ProviderUsageTypeEnumMap = {
  ProviderUsageType.kimi: 'kimi',
  ProviderUsageType.minimax: 'minimax',
  ProviderUsageType.claudeCode: 'claudeCode',
  ProviderUsageType.codex: 'codex',
};

_ProviderUsageWindow _$ProviderUsageWindowFromJson(Map<String, dynamic> json) =>
    _ProviderUsageWindow(
      label: json['label'] as String,
      utilization: (json['utilization'] as num?)?.toDouble() ?? 0.0,
      resetsAtMs: (json['resetsAtMs'] as num?)?.toInt(),
      limit: (json['limit'] as num?)?.toDouble(),
      used: (json['used'] as num?)?.toDouble(),
      remaining: (json['remaining'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ProviderUsageWindowToJson(
  _ProviderUsageWindow instance,
) => <String, dynamic>{
  'label': instance.label,
  'utilization': instance.utilization,
  'resetsAtMs': instance.resetsAtMs,
  'limit': instance.limit,
  'used': instance.used,
  'remaining': instance.remaining,
};

_ProviderUsage _$ProviderUsageFromJson(
  Map<String, dynamic> json,
) => _ProviderUsage(
  accountId: json['accountId'] as String,
  type: $enumDecode(_$ProviderUsageTypeEnumMap, json['type']),
  accountName: json['accountName'] as String?,
  windows:
      (json['windows'] as List<dynamic>?)
          ?.map((e) => ProviderUsageWindow.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ProviderUsageWindow>[],
  extra: json['extra'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  error: json['error'] as String?,
);

Map<String, dynamic> _$ProviderUsageToJson(_ProviderUsage instance) =>
    <String, dynamic>{
      'accountId': instance.accountId,
      'type': _$ProviderUsageTypeEnumMap[instance.type]!,
      'accountName': instance.accountName,
      'windows': instance.windows.map((e) => e.toJson()).toList(),
      'extra': instance.extra,
      'error': instance.error,
    };

_ProviderUsageSummary _$ProviderUsageSummaryFromJson(
  Map<String, dynamic> json,
) => _ProviderUsageSummary(
  usages:
      (json['usages'] as List<dynamic>?)
          ?.map((e) => ProviderUsage.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ProviderUsage>[],
  isLoading: json['isLoading'] as bool? ?? false,
  globalError: json['globalError'] as String?,
);

Map<String, dynamic> _$ProviderUsageSummaryToJson(
  _ProviderUsageSummary instance,
) => <String, dynamic>{
  'usages': instance.usages.map((e) => e.toJson()).toList(),
  'isLoading': instance.isLoading,
  'globalError': instance.globalError,
};
