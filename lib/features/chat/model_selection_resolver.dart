import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/models/settings.dart';
import 'widgets/model_mode.dart';
import 'widgets/permission_mode_selector.dart';

/// Pure result of resolving the permission/model/profile priority chain
/// for a chat session. See [resolveModelSelection].
class ModelSelectionResolution {
  const ModelSelectionResolution({
    required this.resolvedPermissionMode,
    required this.shouldPersistPermissionMode,
    required this.resolvedModelMode,
    required this.resolvedRawModelString,
    required this.resolvedProfile,
    required this.availableProfiles,
    required this.hadGhostProfileReference,
  });

  /// The permission mode to apply.
  final PermissionMode resolvedPermissionMode;

  /// True when [resolvedPermissionMode] was derived from the session (no
  /// per-session draft existed yet) and should be written back to storage
  /// so it becomes the explicit per-session choice on the next load.
  final bool shouldPersistPermissionMode;

  /// The model mode to apply for UI (picker selection) purposes.
  final ChatModelMode resolvedModelMode;

  /// The raw model string to send to the server / persist. For
  /// provider-owned modes (e.g. `GLM-5`, `MiniMax-Text-01`) this differs
  /// from `resolvedModelMode.modeString`, which stays `default`.
  final String? resolvedRawModelString;

  /// The resolved profile, or null if none is selected, or the saved
  /// profile id no longer matches any available profile.
  final AIBackendProfile? resolvedProfile;

  /// Profiles available for the session's flavor (deduped, filtered by
  /// `compatibility.supportsAgent`).
  final List<AIBackendProfile> availableProfiles;

  /// True when a `savedProfileId` was given but no longer matches any
  /// profile in [availableProfiles] (a stale/"ghost" reference) - callers
  /// should clear it from storage.
  final bool hadGhostProfileReference;
}

/// Resolves the saved-draft > session > profile-default > global-default
/// priority chain used to restore permission mode, model mode, and AI
/// backend profile when a chat session is reopened.
///
/// Pure function - no Flutter, no I/O. Callers (e.g.
/// `_ChatScreenState._loadInitialSettings`) read the raw inputs from
/// `DraftStorage` / `Settings` / the `Session`, call this, and act on the
/// flags in the returned [ModelSelectionResolution] (persisting derived
/// values, clearing ghost references) themselves.
ModelSelectionResolution resolveModelSelection({
  required String? savedPermissionMode,
  required String? savedModelMode,
  required String? savedProfileId,
  required String? sessionModelMode,
  required String? sessionPermissionMode,
  required String? flavor,
  required List<AIBackendProfile> settingsProfiles,
  required List<AIBackendProfile> builtInProfiles,
  required String? lastUsedModelMode,
}) {
  var permissionMode = PermissionMode.defaultMode;
  var shouldPersistPermissionMode = false;
  if (savedPermissionMode != null) {
    permissionMode =
        PermissionModeExtension.fromString(savedPermissionMode) ??
        PermissionMode.defaultMode;
  } else if (sessionPermissionMode != null) {
    permissionMode =
        PermissionModeExtension.fromString(sessionPermissionMode) ??
        PermissionMode.defaultMode;
    shouldPersistPermissionMode = true;
  }

  final seen = <String>{};
  final availableProfiles = <AIBackendProfile>[];
  for (final p in [...settingsProfiles, ...builtInProfiles]) {
    if (!p.compatibility.supportsAgent(flavor ?? 'claude')) continue;
    if (seen.add(p.id)) availableProfiles.add(p);
  }

  AIBackendProfile? selectedProfile;
  var hadGhostProfileReference = false;
  // Profile selection is session-scoped: only honor the per-session draft.
  // Falling back to a global last-used profile would leak the most recent
  // choice (e.g. from creating a new session) into every existing session
  // that has no explicit profile saved.
  if (savedProfileId != null) {
    for (final p in availableProfiles) {
      if (p.id == savedProfileId) {
        selectedProfile = p;
        break;
      }
    }
    if (selectedProfile == null) hadGhostProfileReference = true;
  }

  String? rawModelModeString;
  var modelMode = ChatModelMode.defaultModel;
  final selectedProfileOwnsRawCodexModel = profileOwnsRawCodexModel(
    selectedProfile,
  );
  // Models configured on the selected profile are provider-owned raw
  // strings (e.g. 'GLM-5', 'GLM-5:high') that would otherwise normalize
  // to 'default' — the pick would silently never take effect, and an
  // effort-suffixed entry would additionally lose its raw string here.
  final profileModels = selectedProfile?.models;

  String normalizeRaw(String raw) => ChatModelMode.normalizeRawForFlavor(
    raw,
    flavor,
    preserveProviderOwned: selectedProfileOwnsRawCodexModel,
    allowedRawModels: profileModels,
  );

  ChatModelMode normalizeModel(String raw) {
    // Profile-configured models are provider-owned raw strings; a
    // trailing ':effort' must restore as reasoning effort, not parse
    // as a Codex catalog variant that normalization would drop.
    final allowed = ChatModelMode.fromAllowedRaw(raw, profileModels);
    if (allowed != null) return allowed;
    return ChatModelMode.normalizeForFlavor(
      ChatModelMode.fromString(raw),
      flavor,
      allowedRawModels: profileModels,
    );
  }

  // Priority: saved draft > session model > profile default > settings
  // default.
  if (savedModelMode != null) {
    rawModelModeString = normalizeRaw(savedModelMode);
    modelMode = normalizeModel(rawModelModeString);
  } else if (sessionModelMode != null) {
    rawModelModeString = normalizeRaw(sessionModelMode);
    modelMode = normalizeModel(rawModelModeString);
  } else if (selectedProfile?.defaultModelMode case final profileModelMode?) {
    rawModelModeString = normalizeRaw(profileModelMode);
    modelMode = normalizeModel(rawModelModeString);
  } else if (lastUsedModelMode != null) {
    // Fall back to the user's last-used model preference so new sessions
    // inherit the model the user most recently picked. `lastUsedModelMode`
    // is a global preference, so only inherit it when it is compatible
    // with the current flavor. Otherwise a Codex selection (e.g.
    // `gpt-5.5:medium`) leaks into a Claude session and Claude CLI rejects
    // it on respawn.
    final rawCandidate = ChatModelMode.normalizeRawForFlavor(
      lastUsedModelMode,
      flavor,
    );
    final candidate = ChatModelMode.fromString(rawCandidate);
    final available = ChatModelMode.availableForFlavor(flavor);
    if (!candidate.isDefault &&
        (available.contains(candidate) ||
            (flavor == 'codex' && candidate.isCodex))) {
      rawModelModeString = rawCandidate;
      modelMode = candidate;
    }
  }

  return ModelSelectionResolution(
    resolvedPermissionMode: permissionMode,
    shouldPersistPermissionMode: shouldPersistPermissionMode,
    resolvedModelMode: modelMode,
    resolvedRawModelString: rawModelModeString,
    resolvedProfile: selectedProfile,
    availableProfiles: availableProfiles,
    hadGhostProfileReference: hadGhostProfileReference,
  );
}

bool profileOwnsRawCodexModel(AIBackendProfile? profile) {
  if (profile == null || !profile.compatibility.codex) return false;
  if (profile.azureOpenAIConfig != null) return true;
  if (_envValue(profile, 'AZURE_OPENAI_ENDPOINT') != null ||
      _envValue(profile, 'AZURE_OPENAI_DEPLOYMENT_NAME') != null) {
    return true;
  }
  final baseUrl =
      profile.openaiConfig?.baseUrl ?? _envValue(profile, 'OPENAI_BASE_URL');
  return baseUrl != null &&
      !_isOfficialOpenAIBaseUrl(expandEnvDefault(baseUrl));
}

/// Host of the profile's primary backend URL, or null when none can be
/// parsed.
///
/// Profiles are routed by env vars, not by display name — a custom profile
/// called "Qwen" can still point at `api.kimi.com`. Built-in profiles store
/// `${VAR:-default}` refs; the host is taken from the embedded default so
/// the UI matches what the daemon will expand when no process override
/// exists.
String? profileBackendHost(AIBackendProfile? profile) {
  if (profile == null) return null;
  final candidates = <String?>[
    profile.anthropicConfig?.baseUrl,
    profile.openaiConfig?.baseUrl,
    _envValue(profile, 'ANTHROPIC_BASE_URL'),
    _envValue(profile, 'OPENAI_BASE_URL'),
  ];
  for (final raw in candidates) {
    if (raw == null) continue;
    final uri = Uri.tryParse(expandEnvDefault(raw));
    if (uri != null && uri.host.isNotEmpty) return uri.host;
  }
  return null;
}

/// Expand a single `${VAR:-default}` shell-style ref to its default, or
/// return [raw] unchanged when it is not that form.
@visibleForTesting
String expandEnvDefault(String raw) {
  final match = RegExp(r'^\$\{[^:}]+:-(.*)\}$').firstMatch(raw.trim());
  return (match?.group(1) ?? raw).trim();
}

bool profileUsesThirdPartyAnthropicBaseUrl(AIBackendProfile? profile) {
  if (profile == null || !profile.compatibility.claude) return false;
  final baseUrl =
      profile.anthropicConfig?.baseUrl ??
      _envValue(profile, 'ANTHROPIC_BASE_URL');
  if (baseUrl == null) return false;
  final host = Uri.tryParse(expandEnvDefault(baseUrl))?.host.toLowerCase();
  return host != null &&
      host.isNotEmpty &&
      host != 'api.anthropic.com' &&
      !host.endsWith('.anthropic.com');
}

/// Resolves the model label shown as current session status.
///
/// This intentionally does not normalize by session flavor. The picker uses
/// normalization to reject invalid future selections, but the header is an
/// audit of the model already recorded on the session and should show raw
/// provider-owned/custom model strings when present.
ChatModelMode resolveSessionDisplayModel(String? sessionModelMode) {
  final raw = sessionModelMode?.trim();
  if (raw == null || raw.isEmpty) return ChatModelMode.defaultModel;
  return ChatModelMode.fromString(raw);
}

String? _envValue(AIBackendProfile profile, String name) {
  for (final env in profile.environmentVariables) {
    if (env.name != name) continue;
    final trimmed = env.value.trim();
    if (trimmed.isEmpty || trimmed == 'default') return null;
    return trimmed;
  }
  return null;
}

bool _isOfficialOpenAIBaseUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return false;
  if (uri.scheme.toLowerCase() != 'https') return false;
  if (uri.host.toLowerCase() != 'api.openai.com') return false;
  final normalizedPath = uri.path.endsWith('/')
      ? uri.path.substring(0, uri.path.length - 1)
      : uri.path;
  return normalizedPath.isEmpty || normalizedPath == '/v1';
}
