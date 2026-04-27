import '../../../core/rpc/rpc_types.dart';

/// Model mode options exposed by the shared chat composer.
class ChatModelMode {
  const ChatModelMode._({
    required this.label,
    required this.modeString,
    this.modelSlug,
    this.reasoningEffort,
  });

  factory ChatModelMode.fromCodexModel({
    required String slug,
    required String displayName,
    required String effort,
  }) {
    final effortLabel = _capitalizeEffort(effort);
    return ChatModelMode._(
      label: '$displayName $effortLabel',
      modeString: '$slug:$effort',
      modelSlug: slug,
      reasoningEffort: effort,
    );
  }

  /// Use the server-configured default model.
  static const defaultModel = ChatModelMode._(
    label: 'Default',
    modeString: 'default',
  );

  /// Sonnet-class mode for Claude-compatible sessions.
  static const sonnet = ChatModelMode._(label: 'Sonnet', modeString: 'sonnet');

  /// Opus-class mode for Claude-compatible sessions.
  static const opus = ChatModelMode._(label: 'Opus', modeString: 'opus');

  static const values = [defaultModel, sonnet, opus];

  static const claudeModels = [defaultModel, sonnet, opus];

  final String label;
  final String modeString;
  final String? modelSlug;
  final String? reasoningEffort;

  bool get isCodex => modelSlug != null && reasoningEffort != null;

  bool get isDefault => modeString == defaultModel.modeString;

  String get reasoningEffortLabel => _capitalizeEffort(reasoningEffort ?? '');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatModelMode && other.modeString == modeString;

  @override
  int get hashCode => modeString.hashCode;

  /// Parse a wire-format string back to a [ChatModelMode].
  static ChatModelMode fromString(String? value) {
    return switch (value) {
      'sonnet' => sonnet,
      'opus' => opus,
      final raw? when raw.contains(':') => _fromCodexSelection(raw),
      final raw? when raw.isNotEmpty && raw != 'default' => ChatModelMode._(
        label: raw,
        modeString: raw,
      ),
      _ => defaultModel,
    };
  }

  /// Returns the model options available for a session flavor.
  static List<ChatModelMode> availableForFlavor(String? flavor) {
    return switch (flavor) {
      // null means the server hasn't set a flavor yet; default is 'claude'.
      'claude' || null => claudeModels,
      _ => const [defaultModel],
    };
  }

  /// Returns model options filtered by profile compatibility.
  static List<ChatModelMode> availableForProfile({
    required String? flavor,
    required bool claudeCompatible,
    List<ChatModelMode>? codexModels,
  }) {
    if (flavor == 'codex') {
      return codexModels == null || codexModels.isEmpty
          ? const [defaultModel]
          : codexModels;
    }
    final baseModels = availableForFlavor(flavor);
    if (claudeCompatible) return baseModels;
    // Provider-owned model selection uses the selected backend profile.
    return const [defaultModel];
  }

  static List<ChatModelMode> fromCodexCatalog(List<CodexModelInfo> catalog) {
    final models = <ChatModelMode>[defaultModel];
    for (final item in catalog) {
      final efforts = item.supportedReasoningEfforts.isNotEmpty
          ? item.supportedReasoningEfforts
          : [
              if (item.defaultReasoningEffort != null)
                item.defaultReasoningEffort!,
            ];
      for (final effort in efforts) {
        models.add(
          ChatModelMode.fromCodexModel(
            slug: item.slug,
            displayName: item.displayName,
            effort: effort,
          ),
        );
      }
    }
    return models;
  }

  /// Normalizes a model selection so it is valid for the session flavor.
  static ChatModelMode normalizeForFlavor(ChatModelMode model, String? flavor) {
    final available = availableForFlavor(flavor);
    if (available.contains(model) || (flavor == 'codex' && model.isCodex)) {
      return model;
    }
    return defaultModel;
  }

  static ChatModelMode _fromCodexSelection(String raw) {
    final separator = raw.lastIndexOf(':');
    if (separator <= 0 || separator == raw.length - 1) {
      return ChatModelMode._(label: raw, modeString: raw);
    }
    final slug = raw.substring(0, separator);
    final effort = raw.substring(separator + 1);
    return ChatModelMode.fromCodexModel(
      slug: slug,
      displayName: _displayNameFromSlug(slug),
      effort: effort,
    );
  }

  static String _displayNameFromSlug(String slug) {
    return slug
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => part.toUpperCase() == 'GPT' ? 'GPT' : part)
        .join(' ');
  }

  static String _capitalizeEffort(String effort) {
    if (effort.isEmpty) return effort;
    if (effort == 'xhigh') return 'XHigh';
    return '${effort[0].toUpperCase()}${effort.substring(1)}';
  }
}
