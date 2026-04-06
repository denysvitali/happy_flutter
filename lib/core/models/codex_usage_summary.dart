library;

int _asCodexUsageInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is num) return value.toInt();
  return 0;
}

String _asCodexUsageModel(dynamic value) {
  if (value is String && value.isNotEmpty) return value;
  return 'unknown';
}

List<CodexUsageSummaryByModel> _byModelFromJson(dynamic value) {
  if (value is! List) return const <CodexUsageSummaryByModel>[];
  return value
      .whereType<Map>()
      .map((entry) {
        return CodexUsageSummaryByModel.fromJson(
          Map<String, dynamic>.from(entry),
        );
      })
      .toList(growable: false);
}

class CodexUsageSummaryByModel {
  const CodexUsageSummaryByModel({
    required this.model,
    required this.totalTokens,
    required this.threadCount,
  });

  factory CodexUsageSummaryByModel.fromJson(Map<String, dynamic> json) {
    return CodexUsageSummaryByModel(
      model: _asCodexUsageModel(json['model']),
      totalTokens: _asCodexUsageInt(json['totalTokens']),
      threadCount: _asCodexUsageInt(json['threadCount']),
    );
  }

  final String model;
  final int totalTokens;
  final int threadCount;
}

class CodexUsageSummary {
  const CodexUsageSummary({
    required this.totalTokens,
    required this.threadCount,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.databasePath,
    required this.byModel,
  });

  factory CodexUsageSummary.fromJson(Map<String, dynamic> json) {
    return CodexUsageSummary(
      totalTokens: _asCodexUsageInt(json['totalTokens']),
      threadCount: _asCodexUsageInt(json['threadCount']),
      firstSeenAt: _asCodexUsageInt(json['firstSeenAt']),
      lastSeenAt: _asCodexUsageInt(json['lastSeenAt']),
      databasePath: json['databasePath'] as String? ?? '',
      byModel: _byModelFromJson(json['byModel']),
    );
  }

  final int totalTokens;
  final int threadCount;
  final int firstSeenAt;
  final int lastSeenAt;
  final String databasePath;
  final List<CodexUsageSummaryByModel> byModel;
}

class CodexUsageSummaryResponse {
  const CodexUsageSummaryResponse({
    required this.success,
    this.data,
    this.error,
  });

  final bool success;
  final CodexUsageSummary? data;
  final String? error;
}
