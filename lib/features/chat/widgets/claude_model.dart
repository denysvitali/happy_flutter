/// Model options for Claude sessions.
enum ClaudeModel {
  /// Use the server-configured default model.
  defaultModel,

  /// Claude Sonnet.
  sonnet,

  /// Claude Opus.
  opus;

  /// Human-readable label shown in the UI.
  String get label => switch (this) {
    ClaudeModel.defaultModel => 'Default',
    ClaudeModel.sonnet => 'Sonnet',
    ClaudeModel.opus => 'Opus',
  };

  /// Wire-format string sent to the API.
  String get modeString => switch (this) {
    ClaudeModel.defaultModel => 'default',
    ClaudeModel.sonnet => 'sonnet',
    ClaudeModel.opus => 'opus',
  };

  /// Parse a wire-format string back to a [ClaudeModel].
  static ClaudeModel fromString(String? value) => switch (value) {
    'sonnet' => ClaudeModel.sonnet,
    'opus' => ClaudeModel.opus,
    _ => ClaudeModel.defaultModel,
  };

  /// Returns the model options available for a session flavor.
  static List<ClaudeModel> availableForFlavor(String? flavor) {
    return switch (flavor) {
      'claude' => ClaudeModel.values,
      _ => const [ClaudeModel.defaultModel],
    };
  }

  /// Normalizes a model selection so it is valid for the session flavor.
  static ClaudeModel normalizeForFlavor(ClaudeModel model, String? flavor) {
    final available = availableForFlavor(flavor);
    if (available.contains(model)) {
      return model;
    }
    return ClaudeModel.defaultModel;
  }
}
