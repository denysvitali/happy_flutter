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
}
