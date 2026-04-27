/// Model mode options exposed by the shared chat composer.
enum ChatModelMode {
  /// Use the server-configured default model.
  defaultModel,

  /// Sonnet-class mode for Claude-compatible sessions.
  sonnet,

  /// Opus-class mode for Claude-compatible sessions.
  opus,

  /// Codex OpenAI model selections. Wire format is `model:reasoning_effort`.
  gpt55Low,
  gpt55Medium,
  gpt55High,
  gpt55Xhigh,
  gpt54Low,
  gpt54Medium,
  gpt54High,
  gpt54Xhigh,
  gpt54MiniLow,
  gpt54MiniMedium,
  gpt54MiniHigh,
  gpt54MiniXhigh,
  gpt53CodexLow,
  gpt53CodexMedium,
  gpt53CodexHigh,
  gpt53CodexXhigh,
  gpt53CodexSparkLow,
  gpt53CodexSparkMedium,
  gpt53CodexSparkHigh,
  gpt53CodexSparkXhigh,
  gpt52Low,
  gpt52Medium,
  gpt52High,
  gpt52Xhigh;

  /// Human-readable label shown in the UI.
  String get label => switch (this) {
    ChatModelMode.defaultModel => 'Default',
    ChatModelMode.sonnet => 'Sonnet',
    ChatModelMode.opus => 'Opus',
    ChatModelMode.gpt55Low => 'GPT-5.5 Low',
    ChatModelMode.gpt55Medium => 'GPT-5.5 Medium',
    ChatModelMode.gpt55High => 'GPT-5.5 High',
    ChatModelMode.gpt55Xhigh => 'GPT-5.5 XHigh',
    ChatModelMode.gpt54Low => 'GPT-5.4 Low',
    ChatModelMode.gpt54Medium => 'GPT-5.4 Medium',
    ChatModelMode.gpt54High => 'GPT-5.4 High',
    ChatModelMode.gpt54Xhigh => 'GPT-5.4 XHigh',
    ChatModelMode.gpt54MiniLow => 'GPT-5.4 Mini Low',
    ChatModelMode.gpt54MiniMedium => 'GPT-5.4 Mini Medium',
    ChatModelMode.gpt54MiniHigh => 'GPT-5.4 Mini High',
    ChatModelMode.gpt54MiniXhigh => 'GPT-5.4 Mini XHigh',
    ChatModelMode.gpt53CodexLow => 'GPT-5.3 Codex Low',
    ChatModelMode.gpt53CodexMedium => 'GPT-5.3 Codex Medium',
    ChatModelMode.gpt53CodexHigh => 'GPT-5.3 Codex High',
    ChatModelMode.gpt53CodexXhigh => 'GPT-5.3 Codex XHigh',
    ChatModelMode.gpt53CodexSparkLow => 'GPT-5.3 Spark Low',
    ChatModelMode.gpt53CodexSparkMedium => 'GPT-5.3 Spark Medium',
    ChatModelMode.gpt53CodexSparkHigh => 'GPT-5.3 Spark High',
    ChatModelMode.gpt53CodexSparkXhigh => 'GPT-5.3 Spark XHigh',
    ChatModelMode.gpt52Low => 'GPT-5.2 Low',
    ChatModelMode.gpt52Medium => 'GPT-5.2 Medium',
    ChatModelMode.gpt52High => 'GPT-5.2 High',
    ChatModelMode.gpt52Xhigh => 'GPT-5.2 XHigh',
  };

  /// Wire-format string sent to the API.
  String get modeString => switch (this) {
    ChatModelMode.defaultModel => 'default',
    ChatModelMode.sonnet => 'sonnet',
    ChatModelMode.opus => 'opus',
    ChatModelMode.gpt55Low => 'gpt-5.5:low',
    ChatModelMode.gpt55Medium => 'gpt-5.5:medium',
    ChatModelMode.gpt55High => 'gpt-5.5:high',
    ChatModelMode.gpt55Xhigh => 'gpt-5.5:xhigh',
    ChatModelMode.gpt54Low => 'gpt-5.4:low',
    ChatModelMode.gpt54Medium => 'gpt-5.4:medium',
    ChatModelMode.gpt54High => 'gpt-5.4:high',
    ChatModelMode.gpt54Xhigh => 'gpt-5.4:xhigh',
    ChatModelMode.gpt54MiniLow => 'gpt-5.4-mini:low',
    ChatModelMode.gpt54MiniMedium => 'gpt-5.4-mini:medium',
    ChatModelMode.gpt54MiniHigh => 'gpt-5.4-mini:high',
    ChatModelMode.gpt54MiniXhigh => 'gpt-5.4-mini:xhigh',
    ChatModelMode.gpt53CodexLow => 'gpt-5.3-codex:low',
    ChatModelMode.gpt53CodexMedium => 'gpt-5.3-codex:medium',
    ChatModelMode.gpt53CodexHigh => 'gpt-5.3-codex:high',
    ChatModelMode.gpt53CodexXhigh => 'gpt-5.3-codex:xhigh',
    ChatModelMode.gpt53CodexSparkLow => 'gpt-5.3-codex-spark:low',
    ChatModelMode.gpt53CodexSparkMedium => 'gpt-5.3-codex-spark:medium',
    ChatModelMode.gpt53CodexSparkHigh => 'gpt-5.3-codex-spark:high',
    ChatModelMode.gpt53CodexSparkXhigh => 'gpt-5.3-codex-spark:xhigh',
    ChatModelMode.gpt52Low => 'gpt-5.2:low',
    ChatModelMode.gpt52Medium => 'gpt-5.2:medium',
    ChatModelMode.gpt52High => 'gpt-5.2:high',
    ChatModelMode.gpt52Xhigh => 'gpt-5.2:xhigh',
  };

  bool get isCodex => switch (this) {
    ChatModelMode.gpt55Low ||
    ChatModelMode.gpt55Medium ||
    ChatModelMode.gpt55High ||
    ChatModelMode.gpt55Xhigh ||
    ChatModelMode.gpt54Low ||
    ChatModelMode.gpt54Medium ||
    ChatModelMode.gpt54High ||
    ChatModelMode.gpt54Xhigh ||
    ChatModelMode.gpt54MiniLow ||
    ChatModelMode.gpt54MiniMedium ||
    ChatModelMode.gpt54MiniHigh ||
    ChatModelMode.gpt54MiniXhigh ||
    ChatModelMode.gpt53CodexLow ||
    ChatModelMode.gpt53CodexMedium ||
    ChatModelMode.gpt53CodexHigh ||
    ChatModelMode.gpt53CodexXhigh ||
    ChatModelMode.gpt53CodexSparkLow ||
    ChatModelMode.gpt53CodexSparkMedium ||
    ChatModelMode.gpt53CodexSparkHigh ||
    ChatModelMode.gpt53CodexSparkXhigh ||
    ChatModelMode.gpt52Low ||
    ChatModelMode.gpt52Medium ||
    ChatModelMode.gpt52High ||
    ChatModelMode.gpt52Xhigh => true,
    _ => false,
  };

  /// Parse a wire-format string back to a [ChatModelMode].
  static ChatModelMode fromString(String? value) => switch (value) {
    'sonnet' => ChatModelMode.sonnet,
    'opus' => ChatModelMode.opus,
    'gpt-5.5:low' => ChatModelMode.gpt55Low,
    'gpt-5.5:medium' || 'gpt-5.5' => ChatModelMode.gpt55Medium,
    'gpt-5.5:high' => ChatModelMode.gpt55High,
    'gpt-5.5:xhigh' => ChatModelMode.gpt55Xhigh,
    'gpt-5.4:low' => ChatModelMode.gpt54Low,
    'gpt-5.4:medium' || 'gpt-5.4' => ChatModelMode.gpt54Medium,
    'gpt-5.4:high' => ChatModelMode.gpt54High,
    'gpt-5.4:xhigh' => ChatModelMode.gpt54Xhigh,
    'gpt-5.4-mini:low' => ChatModelMode.gpt54MiniLow,
    'gpt-5.4-mini:medium' || 'gpt-5.4-mini' => ChatModelMode.gpt54MiniMedium,
    'gpt-5.4-mini:high' => ChatModelMode.gpt54MiniHigh,
    'gpt-5.4-mini:xhigh' => ChatModelMode.gpt54MiniXhigh,
    'gpt-5.3-codex:low' => ChatModelMode.gpt53CodexLow,
    'gpt-5.3-codex:medium' || 'gpt-5.3-codex' => ChatModelMode.gpt53CodexMedium,
    'gpt-5.3-codex:high' => ChatModelMode.gpt53CodexHigh,
    'gpt-5.3-codex:xhigh' => ChatModelMode.gpt53CodexXhigh,
    'gpt-5.3-codex-spark:low' => ChatModelMode.gpt53CodexSparkLow,
    'gpt-5.3-codex-spark:medium' => ChatModelMode.gpt53CodexSparkMedium,
    'gpt-5.3-codex-spark:high' ||
    'gpt-5.3-codex-spark' => ChatModelMode.gpt53CodexSparkHigh,
    'gpt-5.3-codex-spark:xhigh' => ChatModelMode.gpt53CodexSparkXhigh,
    'gpt-5.2:low' => ChatModelMode.gpt52Low,
    'gpt-5.2:medium' || 'gpt-5.2' => ChatModelMode.gpt52Medium,
    'gpt-5.2:high' => ChatModelMode.gpt52High,
    'gpt-5.2:xhigh' => ChatModelMode.gpt52Xhigh,
    _ => ChatModelMode.defaultModel,
  };

  static const List<ChatModelMode> _codexModels = [
    ChatModelMode.defaultModel,
    ChatModelMode.gpt55Medium,
    ChatModelMode.gpt55Low,
    ChatModelMode.gpt55High,
    ChatModelMode.gpt55Xhigh,
    ChatModelMode.gpt54Medium,
    ChatModelMode.gpt54Low,
    ChatModelMode.gpt54High,
    ChatModelMode.gpt54Xhigh,
    ChatModelMode.gpt54MiniMedium,
    ChatModelMode.gpt54MiniLow,
    ChatModelMode.gpt54MiniHigh,
    ChatModelMode.gpt54MiniXhigh,
    ChatModelMode.gpt53CodexMedium,
    ChatModelMode.gpt53CodexLow,
    ChatModelMode.gpt53CodexHigh,
    ChatModelMode.gpt53CodexXhigh,
    ChatModelMode.gpt53CodexSparkHigh,
    ChatModelMode.gpt53CodexSparkLow,
    ChatModelMode.gpt53CodexSparkMedium,
    ChatModelMode.gpt53CodexSparkXhigh,
    ChatModelMode.gpt52Medium,
    ChatModelMode.gpt52Low,
    ChatModelMode.gpt52High,
    ChatModelMode.gpt52Xhigh,
  ];

  static const List<ChatModelMode> _claudeModels = [
    ChatModelMode.defaultModel,
    ChatModelMode.sonnet,
    ChatModelMode.opus,
  ];

  /// Returns the model options available for a session flavor.
  static List<ChatModelMode> availableForFlavor(String? flavor) {
    return switch (flavor) {
      // null means the server hasn't set a flavor yet — default is 'claude'.
      'claude' || null => _claudeModels,
      'codex' => _codexModels,
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
    if (flavor == 'codex') return baseModels;
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
