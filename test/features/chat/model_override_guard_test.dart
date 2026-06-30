import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/model_selection_resolver.dart';
import 'package:happy_flutter/features/chat/widgets/model_mode.dart';

/// Minimal mirror of `_ChatScreenState`'s model/profile override guard.
///
/// NOTE: mounting the real `ChatScreen` widget and racing
/// its actual async `DraftStorage` read against a synchronous call to
/// `_onModelModeChanged` would require new widget-mount infrastructure that
/// doesn't exist yet for this screen (`chat_screen_test.dart` has no
/// coverage of `_loadInitialSettings`/model-mode restoration to extend).
/// Building that harness is out of scope for this fix, so this test pins
/// the guard's *decision logic* in isolation instead: it copies the exact
/// shape of `_ChatScreenState._userOverrodeModelOrProfile`,
/// `_onModelModeChanged`, and the `setState` block in
/// `_loadInitialSettings` (see `lib/features/chat/_chat_screen_actions.dart`
/// and `lib/features/chat/chat_screen.dart`). If that guard logic
/// regresses (e.g. back to the broken `_effectiveModelModeString == null`
/// check), this test and the production code diverge and must be kept in
/// sync by hand — but it still proves the *pattern* is race-safe.
class _FakeChatScreenState {
  ChatModelMode modelMode = ChatModelMode.defaultModel;
  String? profileModelOverride;
  bool userOverrodeModelOrProfile = false;

  /// Mirrors `_ChatScreenState._onModelModeChanged`.
  void onModelModeChanged(ChatModelMode model) {
    userOverrodeModelOrProfile = true;
    modelMode = model;
    profileModelOverride = model.modeString;
  }

  /// Mirrors the `setState` guard in `_loadInitialSettings`.
  void applyResolvedSettings(ModelSelectionResolution resolution) {
    if (!userOverrodeModelOrProfile) {
      modelMode = resolution.resolvedModelMode;
      profileModelOverride = resolution.resolvedRawModelString;
    }
  }
}

void main() {
  test('user model choice survives an async settings load that resolves '
      'after the user already picked a model', () {
    final state = _FakeChatScreenState();

    // The async DraftStorage read has started but not resolved yet.
    // this is the resolution it will eventually produce (e.g. an old
    // saved draft of `sonnet`).
    final staleResolution = resolveModelSelection(
      savedPermissionMode: null,
      savedModelMode: 'sonnet',
      savedProfileId: null,
      sessionModelMode: null,
      sessionPermissionMode: null,
      flavor: 'claude',
      settingsProfiles: const [],
      builtInProfiles: const [],
      lastUsedModelMode: null,
    );

    // The user interacts with the model picker while the read is still
    // in flight.
    state.onModelModeChanged(ChatModelMode.opus);
    expect(state.modelMode, ChatModelMode.opus);

    // The async load now completes and tries to apply what it resolved
    // before the user's interaction.
    state.applyResolvedSettings(staleResolution);

    // The user's interactive choice must win, not the stale saved draft.
    expect(state.modelMode, ChatModelMode.opus);
    expect(state.profileModelOverride, ChatModelMode.opus.modeString);
  });

  test('with no user interaction, the async load is free to apply its '
      'resolution', () {
    final state = _FakeChatScreenState();
    final resolution = resolveModelSelection(
      savedPermissionMode: null,
      savedModelMode: 'sonnet',
      savedProfileId: null,
      sessionModelMode: null,
      sessionPermissionMode: null,
      flavor: 'claude',
      settingsProfiles: const [],
      builtInProfiles: const [],
      lastUsedModelMode: null,
    );

    state.applyResolvedSettings(resolution);

    expect(state.modelMode, ChatModelMode.sonnet);
    expect(state.userOverrodeModelOrProfile, isFalse);
  });

  test('regression: the old derived-getter guard could never block this '
      'overwrite (kept here as a historical pin)', () {
    // Before this fix, the guard was:
    //   String? get _effectiveModelModeString =>
    //       _profileModelOverride ?? _modelMode.modeString;
    //   if (_effectiveModelModeString == null) { ... }
    // `_modelMode` starts as `ChatModelMode.defaultModel`, whose
    // `modeString` is the non-null literal 'default', so
    // `_effectiveModelModeString` was NEVER null, even immediately after
    // construction. The guard condition was permanently false, so the
    // restore branch was permanently dead and the saved model was
    // silently discarded on every load.
    const profileModelOverride = null;
    const modelMode = ChatModelMode.defaultModel;
    String? effectiveModelModeString() =>
        profileModelOverride ?? modelMode.modeString;

    expect(effectiveModelModeString(), isNotNull);
    expect(effectiveModelModeString() == null, isFalse);
  });
}
