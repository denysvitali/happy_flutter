/// Models for third-party LLM provider usage tracking.
///
/// Mirrors the shape used by https://github.com/denysvitali/llm-usage so that
/// data fetched from Kimi, MiniMax, and future providers can be displayed in a
/// single, consistent UI.
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'provider_usage.freezed.dart';
part 'provider_usage.g.dart';

/// Identifier for a supported third-party usage provider.
enum ProviderUsageType {
  kimi,
  minimax,
  claudeCode,
  codex,
}

/// Default base URL for the Kimi Coding Plan usage API.
///
/// The usage data is served from the coding-plan gateway (NOT the consumer
/// `www.kimi.com` web app). Power users running a custom gateway can override
/// it per account.
const String kimiDefaultBaseUrl = 'https://api.kimi.com/coding/v1';

/// Credentials required to authenticate with Kimi.
///
/// Kimi uses a Bearer Coding Plan API key (`KIMI_API_KEY` /
/// `KIMI_CODING_API_KEY`) against the coding-plan usage API. [baseUrl] defaults
/// to [kimiDefaultBaseUrl] and only needs overriding for custom gateways.
@freezed
abstract class KimiCredentials with _$KimiCredentials {
  const factory KimiCredentials({
    required String apiKey,
    @Default(kimiDefaultBaseUrl) String baseUrl,
    String? accountName,
  }) = _KimiCredentials;

  factory KimiCredentials.fromJson(Map<String, dynamic> json) =>
      _$KimiCredentialsFromJson(json);
}

/// Credentials required to authenticate with MiniMax.
///
/// MiniMax uses cookie-based authentication plus a Group ID that identifies
/// the billing entity.
@freezed
abstract class MiniMaxCredentials with _$MiniMaxCredentials {
  const factory MiniMaxCredentials({
    required String cookie,
    required String groupId,
    String? accountName,
  }) = _MiniMaxCredentials;

  factory MiniMaxCredentials.fromJson(Map<String, dynamic> json) =>
      _$MiniMaxCredentialsFromJson(json);
}

/// Union of credentials for a configured provider account.
@freezed
abstract class ProviderCredentials with _$ProviderCredentials {
  const factory ProviderCredentials.kimi(KimiCredentials credentials) =
      _ProviderCredentialsKimi;

  const factory ProviderCredentials.miniMax(MiniMaxCredentials credentials) =
      _ProviderCredentialsMiniMax;

  factory ProviderCredentials.fromJson(Map<String, dynamic> json) =>
      _$ProviderCredentialsFromJson(json);
}

/// A configured account for a usage provider.
///
/// An account has a display name and the credentials needed to fetch usage.
@freezed
abstract class ProviderAccount with _$ProviderAccount {
  const factory ProviderAccount({
    required String id,
    String? name,
    required ProviderUsageType type,
    required ProviderCredentials credentials,
  }) = _ProviderAccount;

  factory ProviderAccount.fromJson(Map<String, dynamic> json) =>
      _$ProviderAccountFromJson(json);
}

/// A single usage window for a provider account.
///
/// Providers report usage over different time windows (e.g. a daily quota,
/// a 5-hour rate-limit window, or a 7-day rolling window).
@freezed
abstract class ProviderUsageWindow with _$ProviderUsageWindow {
  const factory ProviderUsageWindow({
    required String label,

    /// Utilization as a percentage in the range 0-100.
    @Default(0.0) double utilization,

    /// When this window resets, if known.
    int? resetsAtMs,

    /// Usage limit for the window, if known.
    double? limit,

    /// Amount used in the window, if known.
    double? used,

    /// Amount remaining in the window, if known.
    double? remaining,
  }) = _ProviderUsageWindow;

  factory ProviderUsageWindow.fromJson(Map<String, dynamic> json) =>
      _$ProviderUsageWindowFromJson(json);
}

/// Usage result for a single provider account.
///
/// Either carries one or more usage windows or an error message so that a
/// partial failure on one account does not break the whole overview.
@freezed
abstract class ProviderUsage with _$ProviderUsage {
  const factory ProviderUsage({
    required String accountId,
    required ProviderUsageType type,
    String? accountName,
    @Default(<ProviderUsageWindow>[]) List<ProviderUsageWindow> windows,

    /// Provider-specific extra data (subscription info, feature quotas, ...).
    @Default(<String, dynamic>{}) Map<String, dynamic> extra,

    /// Error message if fetching usage failed for this account.
    String? error,
  }) = _ProviderUsage;

  factory ProviderUsage.fromJson(Map<String, dynamic> json) =>
      _$ProviderUsageFromJson(json);
}

/// Summary of all configured provider accounts.
@freezed
abstract class ProviderUsageSummary with _$ProviderUsageSummary {
  const factory ProviderUsageSummary({
    @Default(<ProviderUsage>[]) List<ProviderUsage> usages,
    @Default(false) bool isLoading,
    String? globalError,
  }) = _ProviderUsageSummary;

  factory ProviderUsageSummary.fromJson(Map<String, dynamic> json) =>
      _$ProviderUsageSummaryFromJson(json);
}
