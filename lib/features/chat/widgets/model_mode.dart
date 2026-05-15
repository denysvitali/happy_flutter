import '../../../core/rpc/rpc_types.dart';

/// Model mode options exposed by the shared chat composer.
class ChatModelMode {
  const ChatModelMode._({
    required this.label,
    required this.modeString,
    this.modelSlug,
    this.reasoningEffort,
    this.flavor,
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
      flavor: 'codex',
    );
  }

  factory ChatModelMode.fromClaudeModel({
    required String tier,
    required String displayName,
    required String effort,
  }) {
    final effortLabel = _capitalizeEffort(effort);
    return ChatModelMode._(
      label: '$displayName $effortLabel',
      modeString: '$tier:$effort',
      modelSlug: tier,
      reasoningEffort: effort,
      flavor: 'claude',
    );
  }

  /// Use the server-configured default model.
  static const defaultModel = ChatModelMode._(
    label: 'Default',
    modeString: 'default',
  );

  /// Sonnet-class mode (no effort override).
  static const sonnet = ChatModelMode._(
    label: 'Sonnet',
    modeString: 'sonnet',
    modelSlug: 'sonnet',
    flavor: 'claude',
  );

  /// Opus-class mode (no effort override).
  static const opus = ChatModelMode._(
    label: 'Opus',
    modeString: 'opus',
    modelSlug: 'opus',
    flavor: 'claude',
  );

  /// Effort levels supported by the `claude` CLI's `--effort` flag.
  static const claudeEfforts = ['low', 'medium', 'high', 'xhigh', 'max'];

  static List<ChatModelMode> _buildClaudeModels() {
    final list = <ChatModelMode>[defaultModel, sonnet];
    for (final effort in claudeEfforts) {
      list.add(
        ChatModelMode.fromClaudeModel(
          tier: 'sonnet',
          displayName: 'Sonnet',
          effort: effort,
        ),
      );
    }
    list.add(opus);
    for (final effort in claudeEfforts) {
      list.add(
        ChatModelMode.fromClaudeModel(
          tier: 'opus',
          displayName: 'Opus',
          effort: effort,
        ),
      );
    }
    return list;
  }

  static const values = [defaultModel, sonnet, opus];

  static final List<ChatModelMode> claudeModels = _buildClaudeModels();

  final String label;
  final String modeString;
  final String? modelSlug;
  final String? reasoningEffort;
  final String? flavor;

  bool get isCodex => flavor == 'codex';

  bool get isClaude => flavor == 'claude';

  bool get hasEffort => reasoningEffort != null;

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
      final raw? when raw.contains(':') => _fromColonSelection(raw),
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

  /// Normalize a stored raw model string for a session flavor while preserving
  /// provider-owned strings that the app cannot parse into picker options.
  static String normalizeRawForFlavor(String value, String? flavor) {
    final parsed = fromString(value);
    final normalized = normalizeForFlavor(parsed, flavor);
    final parsedFlavor = parsed.flavor;
    if (normalized.isDefault && parsedFlavor != null) {
      return normalized.modeString;
    }
    return value;
  }

  static ChatModelMode _fromColonSelection(String raw) {
    final separator = raw.lastIndexOf(':');
    if (separator <= 0 || separator == raw.length - 1) {
      return ChatModelMode._(label: raw, modeString: raw);
    }
    final slug = raw.substring(0, separator);
    final effort = raw.substring(separator + 1);
    if (slug == 'opus' || slug == 'sonnet') {
      return ChatModelMode.fromClaudeModel(
        tier: slug,
        displayName: slug == 'opus' ? 'Opus' : 'Sonnet',
        effort: effort,
      );
    }
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
