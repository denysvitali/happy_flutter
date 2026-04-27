/// Model mode options exposed by the shared chat composer.
///
/// Only Claude-compatible sessions currently expose named modes. Other
/// harnesses keep model selection in the selected backend profile and use the
/// server default on the chat wire.
enum ChatModelMode {
  /// Use the server-configured default model.
  defaultModel,

  /// Sonnet-class mode for Claude-compatible sessions.
  sonnet,

  /// Opus-class mode for Claude-compatible sessions.
  opus;

  /// Human-readable label shown in the UI.
  String get label => switch (this) {
    ChatModelMode.defaultModel => 'Default',
    ChatModelMode.sonnet => 'Sonnet',
    ChatModelMode.opus => 'Opus',
  };

  /// Wire-format string sent to the API.
  String get modeString => switch (this) {
    ChatModelMode.defaultModel => 'default',
    ChatModelMode.sonnet => 'sonnet',
    ChatModelMode.opus => 'opus',
  };

  /// Parse a wire-format string back to a [ChatModelMode].
  static ChatModelMode fromString(String? value) => switch (value) {
    'sonnet' => ChatModelMode.sonnet,
    'opus' => ChatModelMode.opus,
    _ => ChatModelMode.defaultModel,
  };

  /// Returns the model options available for a session flavor.
  static List<ChatModelMode> availableForFlavor(String? flavor) {
    return switch (flavor) {
      // null means the server hasn't set a flavor yet — default is 'claude'.
      'claude' || null => ChatModelMode.values,
      _ => const [ChatModelMode.defaultModel],
    };
  }

  /// Returns model options filtered by profile compatibility.
  /// When a profile supports named chat modes, all modes are available.
  /// For provider-owned model selection, only default is safe.
  static List<ChatModelMode> availableForProfile({
    required String? flavor,
    required bool claudeCompatible,
  }) {
    final baseModels = availableForFlavor(flavor);
    if (claudeCompatible) return baseModels;
    // Provider-owned model selection uses the selected backend profile.
    return const [ChatModelMode.defaultModel];
  }

  /// Normalizes a model selection so it is valid for the session flavor.
  static ChatModelMode normalizeForFlavor(ChatModelMode model, String? flavor) {
    final available = availableForFlavor(flavor);
    if (available.contains(model)) {
      return model;
    }
    return ChatModelMode.defaultModel;
  }
}
