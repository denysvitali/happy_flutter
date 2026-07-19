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
enum ProviderUsageType { kimi, minimax, zai, grok, qwen, claudeCode, codex }

/// Default base URL for the Kimi Coding Plan usage API.
///
/// The usage data is served from the coding-plan gateway (NOT the consumer
/// `www.kimi.com` web app). Power users running a custom gateway can override
/// it per account.
const String kimiDefaultBaseUrl = 'https://api.kimi.com/coding/v1';

/// Default base URL for the Z.AI (Zhipu GLM) Coding Plan usage API.
///
/// The usage/quota endpoints live on the same host as the coding-plan gateway
/// and are NOT part of Z.AI's public API reference — they mirror the internal
/// subscription-management UI also used by community tools (openusage,
/// zai-usage-tracker). A Bearer API key from the Z.AI console authenticates.
/// Power users running a custom gateway can override it per account.
const String zaiDefaultBaseUrl = 'https://api.z.ai';

/// Default base URL for the Grok subscription (Grok Build) API.
///
/// This is the same `cli-chat-proxy.grok.com/v1` host the Grok CLI and
/// grok-proxy use for `/user` and `/billing`. It is NOT a stable public API —
/// its URL, headers, and behavior may change with Grok CLI releases. Power
/// users running grok-proxy or another gateway can override it per account.
const String grokDefaultBaseUrl = 'https://cli-chat-proxy.grok.com/v1';

/// Default base URL for the Qwen Cloud Token Plan usage API.
///
/// Qwen Cloud (the international DashScope portal) does NOT publish a stable
/// usage/credits endpoint — its docs only point at the web console on
/// `home.qwencloud.com`. This host mirrors where that console serves its
/// subscription data; the exact path used by [QwenUsageApi] is a best-effort
/// default and power users who discover the real billing endpoint (e.g. by
/// inspecting the console's network traffic) can override it per account.
/// A Bearer API key from the Qwen Cloud console (`sk-sp-…` for Token Plan
/// Individual) authenticates.
const String qwenDefaultBaseUrl = 'https://home.qwencloud.com';

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
/// MiniMax uses a Bearer API key against the Token Plan remains endpoint.
/// [cookie] and [groupId] remain only so older saved accounts can still decode.
@freezed
abstract class MiniMaxCredentials with _$MiniMaxCredentials {
  const factory MiniMaxCredentials({
    @Default('') String apiKey,
    @Default('') String cookie,
    @Default('') String groupId,
    String? accountName,
  }) = _MiniMaxCredentials;

  factory MiniMaxCredentials.fromJson(Map<String, dynamic> json) =>
      _$MiniMaxCredentialsFromJson(json);
}

/// Credentials required to authenticate with Z.AI (Zhipu GLM).
///
/// Z.AI uses a Bearer API key (created in the Z.AI console) against the
/// internal usage/quota endpoints. [baseUrl] defaults to [zaiDefaultBaseUrl]
/// and only needs overriding for custom gateways.
@freezed
abstract class ZaiCredentials with _$ZaiCredentials {
  const factory ZaiCredentials({
    required String apiKey,
    @Default(zaiDefaultBaseUrl) String baseUrl,
    String? accountName,
  }) = _ZaiCredentials;

  factory ZaiCredentials.fromJson(Map<String, dynamic> json) =>
      _$ZaiCredentialsFromJson(json);
}

/// Credentials required to authenticate with Grok (xAI subscription).
///
/// Grok uses the OAuth access token from a Grok CLI / grok-proxy session
/// (`~/.grok/auth.json` or `~/.config/grok-proxy/auth.json`, field
/// `access_token`) against the account service on the subscription host.
/// [baseUrl] defaults to [grokDefaultBaseUrl] and only needs overriding for
/// custom gateways.
@freezed
abstract class GrokCredentials with _$GrokCredentials {
  const factory GrokCredentials({
    required String accessToken,
    @Default(grokDefaultBaseUrl) String baseUrl,
    String? accountName,
  }) = _GrokCredentials;

  factory GrokCredentials.fromJson(Map<String, dynamic> json) =>
      _$GrokCredentialsFromJson(json);
}

/// Credentials required to authenticate with Qwen Cloud (Token Plan).
///
/// Qwen Cloud uses a Bearer API key from the console (`sk-sp-…` keys for
/// Token Plan Individual) against the subscription host. [baseUrl] defaults
/// to [qwenDefaultBaseUrl] and only needs overriding for custom gateways or
/// a corrected billing path.
@freezed
abstract class QwenCredentials with _$QwenCredentials {
  const factory QwenCredentials({
    required String apiKey,
    @Default(qwenDefaultBaseUrl) String baseUrl,
    String? accountName,
  }) = _QwenCredentials;

  factory QwenCredentials.fromJson(Map<String, dynamic> json) =>
      _$QwenCredentialsFromJson(json);
}

/// Union of credentials for a configured provider account.
@freezed
abstract class ProviderCredentials with _$ProviderCredentials {
  const factory ProviderCredentials.kimi(KimiCredentials credentials) =
      _ProviderCredentialsKimi;

  const factory ProviderCredentials.miniMax(MiniMaxCredentials credentials) =
      _ProviderCredentialsMiniMax;

  const factory ProviderCredentials.zai(ZaiCredentials credentials) =
      _ProviderCredentialsZai;

  const factory ProviderCredentials.grok(GrokCredentials credentials) =
      _ProviderCredentialsGrok;

  const factory ProviderCredentials.qwen(QwenCredentials credentials) =
      _ProviderCredentialsQwen;

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
