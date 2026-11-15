import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/models/favorite_model.dart';
import '../../core/models/session.dart';
import '../../core/models/settings.dart';
import '../../core/utils/session_provider.dart'
    show
        metadataRecordsClientProfile,
        sessionClientProfileId,
        sessionRecordedModel,
        sessionUsesThirdPartyAnthropicBaseUrl;
import 'widgets/model_mode.dart';
import 'widgets/permission_mode_selector.dart';

export '../../core/utils/model_selection.dart' show primeAgentModelSelection;

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

/// Resolves the saved-draft > synced session > server session >
/// provider-favorite > profile-default > global-default priority chain used
/// to restore permission mode, model mode, and AI backend profile when a chat
/// session is reopened.
///
/// Pure function - no Flutter, no I/O. Callers (e.g.
/// `_ChatScreenState._loadInitialSettings`) read the raw inputs from
/// `DraftStorage` / `Settings` / the `Session`, call this, and act on the
/// flags in the returned [ModelSelectionResolution] (persisting derived
/// values, clearing ghost references) themselves.
///
/// [sessionMetadata] carries the provider identity the daemon recorded on
/// the session itself (`clientProfileId` and the launch routing). Chat state
/// is device-local, so a session opened on another device, after app data
/// was cleared, or after its provider profile was recreated has no matching
/// local draft; without the session's own record the picker then falls back
/// to `Default` while the daemon keeps running the gateway model.
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
  Map<String, String> favoriteModelsByProfile = const {},
  List<PrimeAgentModelInfo>? opencodeModels,
  List<PrimeAgentModelInfo>? harModels,
  String? syncedSessionPermissionMode,
  String? lastUsedPermissionMode,
  Metadata? sessionMetadata,
}) {
  if (flavor == 'har') {
    // The launched process owns its model; stale picker intent must never
    // restart a conversation that cannot be durably resumed.
    final catalog = ChatModelMode.fromHarCatalog(harModels ?? const []);
    final current = sessionModelMode;
    final model = current == null || current.isEmpty || current == 'default'
        ? ChatModelMode.defaultModel
        : catalog.where((m) => m.modeString == current).firstOrNull ??
              ChatModelMode.fromHarCatalog([
                PrimeAgentModelInfo(id: current, name: current),
              ]).single;
    final profile = settingsProfiles
        .where((p) => p.id == savedProfileId)
        .firstOrNull;
    return ModelSelectionResolution(
      resolvedPermissionMode: PermissionMode.bypassPermissions,
      shouldPersistPermissionMode: savedPermissionMode != 'bypassPermissions',
      resolvedModelMode: model,
      resolvedRawModelString: model.modeString,
      resolvedProfile: profile,
      availableProfiles: const [],
      hadGhostProfileReference: false,
    );
  }
  var permissionMode = PermissionMode.defaultMode;
  var shouldPersistPermissionMode = false;
  if (savedPermissionMode != null) {
    permissionMode =
        PermissionModeExtension.fromString(savedPermissionMode) ??
        PermissionMode.defaultMode;
  } else if (syncedSessionPermissionMode != null) {
    permissionMode =
        PermissionModeExtension.fromString(syncedSessionPermissionMode) ??
        PermissionMode.defaultMode;
    shouldPersistPermissionMode = true;
  } else if (sessionPermissionMode != null) {
    permissionMode =
        PermissionModeExtension.fromString(sessionPermissionMode) ??
        PermissionMode.defaultMode;
    shouldPersistPermissionMode = true;
  } else if (lastUsedPermissionMode != null) {
    // Older versions only synchronized this global value. Use it as a
    // migration fallback for sessions that have no scoped or server value;
    // new picker changes are stored in `permissionModesBySession`.
    permissionMode =
        PermissionModeExtension.fromString(lastUsedPermissionMode) ??
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
  // The daemon records the profile it launched the session with, and that
  // record outranks local state: a draft belongs to this device's app data
  // and can vanish (reinstall, app data clear, another device, a recreated
  // profile) while the running process keeps its routing. A recorded
  // `default` is an explicit "no profile" choice and must not inherit a
  // leftover local profile either.
  final recordedProfileId = sessionClientProfileId(sessionMetadata);
  final recordedProfileChoice = metadataRecordsClientProfile(sessionMetadata);
  if (recordedProfileChoice) {
    selectedProfile = null;
    hadGhostProfileReference = false;
    for (final p in availableProfiles) {
      if (recordedProfileId != null && p.id == recordedProfileId) {
        selectedProfile = p;
        break;
      }
    }
    if (recordedProfileId != null && selectedProfile == null) {
      // The daemon ran a profile this device no longer has: its model and
      // routing still belong to that session, so keep them verbatim instead
      // of presenting the wrong provider as "Default".
      hadGhostProfileReference = true;
    }
  }
  // Routing the session was actually launched with. When the recorded
  // profile is unknown locally (or the session recorded routing without a
  // profile), the recorded model belongs to that provider and must survive
  // normalization verbatim.
  final sessionUsesThirdParty = sessionUsesThirdPartyAnthropicBaseUrl(
    sessionMetadata,
  );

  if (flavor == 'opencode') {
    final catalog = ChatModelMode.fromOpenCodeCatalog(
      opencodeModels ?? const [],
    );
    final model =
        catalog.where((m) => m.modeString == sessionModelMode).firstOrNull ??
        ChatModelMode.defaultModel;
    return ModelSelectionResolution(
      resolvedPermissionMode: permissionMode,
      shouldPersistPermissionMode: shouldPersistPermissionMode,
      resolvedModelMode: model,
      resolvedRawModelString: model.modeString,
      resolvedProfile: selectedProfile,
      availableProfiles: availableProfiles,
      hadGhostProfileReference: hadGhostProfileReference,
    );
  }

  String? rawModelModeString;
  var modelMode = ChatModelMode.defaultModel;
  final selectedProfileOwnsRawCodexModel = profileOwnsRawCodexModel(
    selectedProfile,
  );
  // Third-party Anthropic-compatible gateways (DeepSeek, Grok proxy,
  // MiniMax, …) serve provider-owned model slugs that neither the Claude
  // tier catalog nor any allowlist knows. Their selections — especially
  // `<slug>:<effort>` drafts, which would otherwise parse as Codex
  // variants and collapse to 'default' on reopen — must survive
  // normalization verbatim.
  final selectedProfileOwnsRawModels =
      selectedProfileOwnsRawCodexModel ||
      profileUsesThirdPartyAnthropicBaseUrl(selectedProfile) ||
      // The session itself recorded third-party routing. That outranks the
      // local profile, which may be missing or belong to another provider.
      sessionUsesThirdParty;
  // Models configured on the selected profile are provider-owned raw
  // strings (e.g. 'GLM-5', 'GLM-5:high') that would otherwise normalize
  // to 'default' — the pick would silently never take effect, and an
  // effort-suffixed entry would additionally lose its raw string here.
  final profileModels = selectedProfile?.models;

  String normalizeRaw(String raw) => ChatModelMode.normalizeRawForFlavor(
    raw,
    flavor,
    preserveProviderOwned: selectedProfileOwnsRawModels,
    allowedRawModels: profileModels,
  );

  ChatModelMode normalizeModel(String raw) {
    // Profile-configured models are provider-owned raw strings; a
    // trailing ':effort' must restore as reasoning effort, not parse
    // as a Codex catalog variant that normalization would drop.
    final allowed = ChatModelMode.fromAllowedRaw(
      raw,
      profileModels,
      flavor: flavor,
    );
    if (allowed != null) return allowed;
    return ChatModelMode.normalizeForFlavor(
      ChatModelMode.fromString(raw),
      flavor,
      allowedRawModels: profileModels,
      preserveProviderOwned: selectedProfileOwnsRawModels,
    );
  }

  // No explicit pick anywhere: fall back to the provider's saved favorite.
  // The ghost guard keeps a favorite belonging to a vanished profile from
  // silently steering a session that no longer has that profile.
  final favoriteModel = hadGhostProfileReference
      ? null
      : favoriteModelForProvider(
          favoriteModelsByProfile,
          selectedProfile,
          flavor,
        );

  // Priority: saved draft > session model > provider favorite > profile
  // default > settings default.
  //
  // A recorded provider choice (`clientProfileId`) scopes local picks to the
  // running configuration: draft/favorite/global values that normalize to
  // `default` describe a different provider and are dropped, so the
  // session's own record (or its Default) decides instead. A draft that
  // still resolves to a provider-owned model wins - that is the user's
  // current pick for this launch.
  void applyPick(String raw) {
    final normalized = normalizeRaw(raw);
    final resolved = normalizeModel(normalized);
    if (recordedProfileChoice) {
      if (resolved.isDefault) return;
      // A Claude alias/full id can never be served by the gateway this
      // session actually runs on (the daemon aborts with
      // provider_model_mismatch), so a leftover local pick for another
      // provider is dropped instead of being sent as this session's model.
      if (sessionUsesThirdParty &&
          (resolved.isClaude ||
              resolved.modelSlug?.startsWith('claude-') == true)) {
        return;
      }
    }
    rawModelModeString = normalized;
    modelMode = resolved;
  }

  if (savedModelMode != null) {
    applyPick(savedModelMode);
  } else if (sessionModelMode != null) {
    applyPick(sessionModelMode);
  } else if (favoriteModel != null) {
    applyPick(favoriteModel);
  } else if (selectedProfile?.defaultModelMode case final profileModelMode?) {
    applyPick(profileModelMode);
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
    // A Claude alias can never be served by a third-party gateway profile
    // (the daemon aborts with provider_model_mismatch), so the global
    // last-used pick must not leak into a gateway session.
    final aliasOnGateway =
        flavor != 'codex' &&
        candidate.isClaude &&
        (sessionUsesThirdParty ||
            profileUsesThirdPartyAnthropicBaseUrl(selectedProfile));
    if (!candidate.isDefault &&
        !aliasOnGateway &&
        (available.contains(candidate) ||
            (flavor == 'codex' && candidate.isCodex))) {
      rawModelModeString = rawCandidate;
      modelMode = candidate;
    }
  }

  // Last resort: the model the daemon recorded for this running session.
  // Nothing local explains this session (no draft, no session model column,
  // no resolvable profile), yet the process is demonstrably on a model -
  // showing `Default` there misreports the provider. This is an audit of
  // what is running, so it stays verbatim even when no catalog lists it.
  if (modelMode.isDefault) {
    final recordedModel = sessionRecordedModel(sessionMetadata);
    if (recordedModel != null &&
        !ChatModelMode.fromString(recordedModel).isDefault) {
      final preserved = normalizeRaw(recordedModel);
      if (preserved != ChatModelMode.defaultModel.modeString) {
        rawModelModeString = preserved;
        modelMode = ChatModelMode.fromString(preserved);
      }
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
  if (profile.codexProviders.isNotEmpty || profile.models.isNotEmpty) {
    return true;
  }
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
