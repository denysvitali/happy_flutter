/// Provider identity a session was actually launched with.
///
/// The daemon records this on the session itself (`clientProfileId`) - and
/// its routing snapshot on the encrypted metadata - precisely so a client can
/// tell what is running without depending on its own device-local draft state.
/// A chat opened on another device, after app-data was cleared, or after the
/// provider profile was recreated has no local draft, but the session's
/// recorded identity is still authoritative.
library;

import '../models/session.dart';

/// Expand a single `${VAR:-default}` shell-style ref to its default, or
/// return [raw] unchanged when it is not that form.
///
/// Built-in profiles store expansion refs rather than bare URLs, so a routing
/// snapshot may carry them too.
String expandEnvDefault(String raw) {
  final match = RegExp(r'^\$\{[^:}]+:-(.*)\}$').firstMatch(raw.trim());
  return (match?.group(1) ?? raw).trim();
}

/// Whether [raw] is the official Anthropic endpoint (an https URL on
/// `api.anthropic.com`, with no path or `/v1`).
bool isOfficialAnthropicBaseUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return false;
  if (uri.scheme.toLowerCase() != 'https') return false;
  if (uri.host.toLowerCase() != 'api.anthropic.com') return false;
  final path = uri.path.endsWith('/')
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  return path.isEmpty || path == '/v1';
}

/// Whether [raw] is the official OpenAI endpoint (an https URL on
/// `api.openai.com`, with no path or `/v1`).
bool isOfficialOpenAIBaseUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return false;
  if (uri.scheme.toLowerCase() != 'https') return false;
  if (uri.host.toLowerCase() != 'api.openai.com') return false;
  final path = uri.path.endsWith('/')
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  return path.isEmpty || path == '/v1';
}

/// The app profile the daemon recorded for this session, or null when the
/// session runs without one.
///
/// `default` is the wire marker for an explicit "no profile" choice, so it is
/// normalized to null. Use [metadataRecordsClientProfile] to tell that apart
/// from "this daemon recorded nothing".
String? sessionClientProfileId(Metadata? metadata) {
  final raw = metadata?.clientProfileId?.trim();
  if (raw == null || raw.isEmpty || raw == 'default') return null;
  return raw;
}

/// True when the session metadata carries the daemon's profile choice
/// (including the explicit `default` marker).
bool metadataRecordsClientProfile(Metadata? metadata) {
  final raw = metadata?.clientProfileId?.trim();
  return raw != null && raw.isNotEmpty;
}

/// The model the daemon recorded for the running session, or null when it
/// recorded the sentinel `default` / nothing.
///
/// This is the launched model (provider-owned ids included); it is an audit of
/// what is running, not a picker preference.
String? sessionRecordedModel(Metadata? metadata) {
  final raw = metadata?.model?.trim();
  if (raw == null || raw.isEmpty || raw == 'default') return null;
  return raw;
}

/// Base URL this session's Anthropic-compatible traffic was launched
/// against, or null when the session recorded none.
String? sessionAnthropicBaseUrl(Metadata? metadata) =>
    _nonEmptyBaseUrl(metadata?.providerRouting?.anthropicBaseUrl);

/// Base URL this session's OpenAI-compatible traffic was launched against,
/// or null when the session recorded none.
String? sessionOpenAIApiBaseUrl(Metadata? metadata) =>
    _nonEmptyBaseUrl(metadata?.providerRouting?.openaiBaseUrl);

String? _nonEmptyBaseUrl(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty || trimmed == 'default') return null;
  final expanded = expandEnvDefault(trimmed);
  return expanded.isEmpty ? null : expanded;
}

/// True when the session itself is routed to a third-party
/// Anthropic-compatible gateway (for example llm-proxy), regardless of what
/// the app's local profile draft says.
bool sessionUsesThirdPartyAnthropicBaseUrl(Metadata? metadata) {
  final baseUrl = sessionAnthropicBaseUrl(metadata);
  return baseUrl != null && !isOfficialAnthropicBaseUrl(baseUrl);
}

/// True when the session itself is routed to a third-party OpenAI-compatible
/// provider.
bool sessionUsesThirdPartyOpenAIBaseUrl(Metadata? metadata) {
  final baseUrl = sessionOpenAIApiBaseUrl(metadata);
  return baseUrl != null && !isOfficialOpenAIBaseUrl(baseUrl);
}

/// True when any recorded provider routing on the session is third-party.
bool sessionUsesThirdPartyProvider(Metadata? metadata) =>
    sessionUsesThirdPartyAnthropicBaseUrl(metadata) ||
    sessionUsesThirdPartyOpenAIBaseUrl(metadata);

/// Picker-eligible models implied by the session's recorded launch. Returns
/// null when the session recorded nothing.
///
/// Used so a chat whose local profile draft was lost still offers and
/// preserves the model it is actually running instead of collapsing to
/// `Default`.
List<String>? sessionRecordedModels(Metadata? metadata) {
  final recorded = sessionRecordedModel(metadata);
  return recorded == null ? null : [recorded];
}
