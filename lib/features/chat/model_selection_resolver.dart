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

  // Priority: saved draft > session model > profile default > settings
  // default.
  if (savedModelMode != null) {
    rawModelModeString = ChatModelMode.normalizeRawForFlavor(
      savedModelMode,
      flavor,
    );
    modelMode = ChatModelMode.normalizeForFlavor(
      ChatModelMode.fromString(savedModelMode),
      flavor,
    );
  } else if (sessionModelMode != null) {
    rawModelModeString = ChatModelMode.normalizeRawForFlavor(
      sessionModelMode,
      flavor,
    );
    modelMode = ChatModelMode.normalizeForFlavor(
      ChatModelMode.fromString(sessionModelMode),
      flavor,
    );
  } else if (selectedProfile?.defaultModelMode case final profileModelMode?) {
    rawModelModeString = ChatModelMode.normalizeRawForFlavor(
      profileModelMode,
      flavor,
    );
    modelMode = ChatModelMode.normalizeForFlavor(
      ChatModelMode.fromString(profileModelMode),
      flavor,
    );
  } else if (lastUsedModelMode != null) {
    // Fall back to the user's last-used model preference so new sessions
    // inherit the model the user most recently picked. `lastUsedModelMode`
    // is a global preference, so only inherit it when it is compatible
    // with the current flavor. Otherwise a Codex selection (e.g.
    // `gpt-5.5:medium`) leaks into a Claude session and Claude CLI rejects
    // it on respawn.
    final candidate = ChatModelMode.fromString(lastUsedModelMode);
    final available = ChatModelMode.availableForFlavor(flavor);
    if (available.contains(candidate) ||
        (flavor == 'codex' && candidate.isCodex)) {
      rawModelModeString = lastUsedModelMode;
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
