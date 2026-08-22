import '../../../core/models/built_in_profiles.dart';
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

  static const _knownSlugs = {'fable', 'sonnet', 'opus'};

  factory ChatModelMode.custom({required String slug, String? effort}) {
    final effortLabel = effort != null ? _capitalizeEffort(effort) : null;
    return ChatModelMode._(
      label: effortLabel != null ? '$slug $effortLabel' : slug,
      modeString: effort != null ? '$slug:$effort' : slug,
      modelSlug: slug,
      reasoningEffort: effort,
      flavor: 'claude',
    );
  }

  /// A user-entered Codex model ID that is not present in the machine catalog.
  factory ChatModelMode.customCodex({required String slug, String? effort}) {
    final effortLabel = effort != null ? _capitalizeEffort(effort) : null;
    return ChatModelMode._(
      label: effortLabel != null ? '$slug $effortLabel' : slug,
      modeString: effort != null ? '$slug:$effort' : slug,
      modelSlug: slug,
      reasoningEffort: effort,
      flavor: 'codex',
    );
  }

  /// Use the server-configured default model.
  static const defaultModel = ChatModelMode._(
    label: 'Default',
    modeString: 'default',
  );

  /// Fable-class mode (Claude Fable 5; no effort override).
  static const fable = ChatModelMode._(
    label: 'Fable',
    modeString: 'fable',
    modelSlug: 'fable',
    flavor: 'claude',
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

  /// Canonical reasoning efforts offered for a provider-owned Codex
  /// model. The app cannot query a third-party provider for the set its
  /// model supports, so it exposes the standard Codex range. The model
  /// slug itself is fixed by the selected profile; only the effort is
  /// user-selectable (see [providerOwnedCodexEfforts]).
  static const codexEfforts = ['low', 'medium', 'high'];

  /// Suffix the Claude Code CLI parses locally to open a 1M-token context
  /// window. It is stripped client-side before the model ID reaches the
  /// provider, so `deepseek-v4-pro[1m]` is sent as `deepseek-v4-pro` with a
  /// 1M budget.
  static const oneMillionSuffix = '[1m]';

  /// Whether this selection opts into the 1M context window.
  bool get has1MContext => modeString.endsWith(oneMillionSuffix);

  /// Strip a trailing 1M suffix, if present.
  static String stripOneMillionSuffix(String raw) {
    if (!raw.endsWith(oneMillionSuffix)) return raw;
    return raw.substring(0, raw.length - oneMillionSuffix.length);
  }

  /// Append the 1M suffix, if not already present.
  static String withOneMillionSuffix(String raw) =>
      raw.endsWith(oneMillionSuffix) ? raw : '$raw$oneMillionSuffix';

  /// Return a copy of this selection that opts into the 1M context window.
  /// The label is left unchanged so the chip can render a separate badge.
  ChatModelMode withOneMillionContext() {
    if (has1MContext) return this;
    return ChatModelMode._(
      label: label,
      modeString: '$modeString$oneMillionSuffix',
      modelSlug: modelSlug,
      reasoningEffort: reasoningEffort,
      flavor: flavor,
    );
  }

  static List<ChatModelMode> _buildClaudeModels() {
    final list = <ChatModelMode>[defaultModel];
    const tiers = [
      (base: fable, displayName: 'Fable'),
      (base: sonnet, displayName: 'Sonnet'),
      (base: opus, displayName: 'Opus'),
    ];
    for (final tier in tiers) {
      list.add(tier.base);
      for (final effort in claudeEfforts) {
        list.add(
          ChatModelMode.fromClaudeModel(
            tier: tier.base.modeString,
            displayName: tier.displayName,
            effort: effort,
          ),
        );
      }
    }
    return list;
  }

  static const values = [defaultModel, fable, sonnet, opus];

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

  bool get isCustom =>
      !isDefault && !isCodex && !_knownSlugs.contains(modelSlug);

  String get reasoningEffortLabel => _capitalizeEffort(reasoningEffort ?? '');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatModelMode && other.modeString == modeString;

  @override
  int get hashCode => modeString.hashCode;

  /// Parse a wire-format string back to a [ChatModelMode].
  static ChatModelMode fromString(String? value) {
    final trimmed = value?.trim();
    final has1M = trimmed != null && trimmed.endsWith(oneMillionSuffix);
    final base = has1M
        ? trimmed.substring(0, trimmed.length - oneMillionSuffix.length)
        : trimmed;
    final parsed = _fromStringBase(base);
    return has1M ? parsed.withOneMillionContext() : parsed;
  }

  static ChatModelMode _fromStringBase(String? value) {
    return switch (value) {
      'fable' => fable,
      'sonnet' => sonnet,
      'opus' => opus,
      final raw? when raw.contains(':') => _fromColonSelection(raw),
      final raw? when raw.isNotEmpty && raw != 'default' =>
        isKnownCodexModelString(raw)
            ? ChatModelMode._(
                label: _displayNameFromSlug(raw),
                modeString: raw,
                modelSlug: raw,
                flavor: 'codex',
              )
            : _isClaudeModelSlug(raw)
            ? ChatModelMode.custom(slug: raw)
            : ChatModelMode._(label: raw, modeString: raw),
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
  ///
  /// When [profileModels] is non-empty, the profile has a custom
  /// model list configured in the provider setup screen. Those
  /// models replace the default flavor catalog (Claude tiers,
  /// Codex catalog) so the user picks from the models they
  /// actually configured. The [defaultModel] entry is always
  /// included as the first option.
  ///
  /// When [providerOwnedCodexModel] is non-null (a Codex session
  /// whose selected profile supplies its own model, e.g. Azure
  /// OpenAI or a Qwen Token Plan gateway), the model slug is
  /// fixed by the profile but the user can still vary the
  /// reasoning effort - see [providerOwnedCodexEfforts].
  static List<ChatModelMode> availableForProfile({
    required String? flavor,
    required bool claudeCompatible,
    bool allowClaudeAliases = true,
    List<ChatModelMode>? codexModels,
    String? providerOwnedCodexModel,
    List<String>? profileModels,
  }) {
    if (flavor == 'codex') {
      final owned = providerOwnedCodexModel?.trim();
      if (owned != null &&
          owned.isNotEmpty &&
          owned != defaultModel.modeString) {
        return providerOwnedCodexEfforts(owned);
      }
      return codexModels == null || codexModels.isEmpty
          ? const [defaultModel]
          : codexModels;
    }
    // Profile has custom models configured — expand each into an
    // effort family so the user can check and set the reasoning
    // effort per session (same pattern as [providerOwnedCodexEfforts]).
    // Entries that differ only by a `:effort` suffix collapse into
    // one family.
    if (profileModels != null && profileModels.isNotEmpty) {
      return [
        defaultModel,
        ..._expandProfileModelFamilies(profileModels),
      ];
    }
    final baseModels = availableForFlavor(flavor);
    if (claudeCompatible && allowClaudeAliases) return baseModels;
    // Provider-owned model selection uses the selected backend profile.
    return const [defaultModel];
  }

  /// Builds picker options for a provider-owned Codex model.
  ///
  /// The model slug is fixed by the selected profile (parsed from
  /// [rawModel], dropping any existing `:effort` suffix), so the family
  /// row exposes a single model. The user can still vary the reasoning
  /// effort: the first entry is the effort-less "Auto" variant (the
  /// provider's own default), followed by one entry per [codexEfforts].
  /// Selecting an effort emits the wire-format `slug:effort` string.
  static List<ChatModelMode> providerOwnedCodexEfforts(String rawModel) {
    final slug = _stripEffortSuffix(rawModel.trim());
    if (slug.isEmpty) return const [defaultModel];
    return [
      ChatModelMode._(
        label: slug,
        modeString: slug,
        modelSlug: slug,
        flavor: 'codex',
      ),
      for (final effort in codexEfforts)
        ChatModelMode.fromCodexModel(
          slug: slug,
          displayName: slug,
          effort: effort,
        ),
    ];
  }

  /// Builds picker options for a profile-configured custom model on a
  /// Claude-compatible session (e.g. an OpenRouter slug from the
  /// profile's model list).
  ///
  /// Mirrors [providerOwnedCodexEfforts]: the first entry is the
  /// effort-less base variant (the provider's own default), followed by
  /// one entry per [claudeEfforts]. Selecting an effort emits the
  /// wire-format `slug:effort` string, which the daemon maps to the
  /// CLI's `--effort` flag.
  static List<ChatModelMode> providerOwnedClaudeEfforts(String rawModel) {
    final slug = _stripEffortSuffix(rawModel.trim());
    if (slug.isEmpty) return const [];
    return [
      ChatModelMode.custom(slug: slug),
      for (final effort in claudeEfforts)
        ChatModelMode.custom(slug: slug, effort: effort),
    ];
  }

  /// Expands a profile's configured model list into effort families,
  /// deduping slugs that differ only by an effort suffix.
  static List<ChatModelMode> _expandProfileModelFamilies(
    List<String> models,
  ) {
    final families = <ChatModelMode>[];
    final seenSlugs = <String>{};
    for (final raw in models) {
      final slug = _stripEffortSuffix(raw.trim());
      if (slug.isEmpty || !seenSlugs.add(slug)) continue;
      families.addAll(providerOwnedClaudeEfforts(slug));
    }
    return families;
  }

  /// Parses a raw string from a profile's configured model list into its
  /// picker representation, keeping a trailing `:effort` suffix as
  /// [reasoningEffort] instead of misreading it as a Codex catalog
  /// variant. Returns null when the string is not allowlisted — neither
  /// verbatim nor as a known-effort suffix on an allowlisted base slug.
  ///
  /// The returned mode keeps the raw string verbatim as its
  /// [modeString] so saved drafts round-trip byte-for-byte.
  static ChatModelMode? fromAllowedRaw(String? raw, List<String>? allowed) {
    final trimmed = raw?.trim();
    if (trimmed == null ||
        trimmed.isEmpty ||
        allowed == null ||
        allowed.isEmpty) {
      return null;
    }
    final base = _stripEffortSuffix(trimmed);
    final hasEffortSuffix = base != trimmed;
    final baseAllowed = _isAllowedRawModel(base, allowed);
    if (!baseAllowed && !_isAllowedRawModel(trimmed, allowed)) {
      return null;
    }
    final effort = hasEffortSuffix
        ? trimmed.substring(base.length + 1)
        : null;
    return ChatModelMode._(
      // Same shape as [ChatModelMode.custom]: "slug Effort" reads better
      // in chips than the raw wire string.
      label: effort != null ? '$base ${_capitalizeEffort(effort)}' : base,
      modeString: trimmed,
      modelSlug: base,
      reasoningEffort: effort,
      flavor: 'claude',
    );
  }

  /// Whether [raw] is a valid selection against a profile's configured
  /// model list: verbatim, or `base:effort` with an allowlisted base and
  /// a known effort level.
  static bool isAllowedRawSelection(String raw, List<String>? allowed) =>
      fromAllowedRaw(raw, allowed) != null;

  /// Drops a trailing `:effort` suffix from a provider-owned model string
  /// so the base slug can be reused across effort variants. Only known
  /// effort suffixes are stripped, so model slugs that legitimately
  /// contain a colon are left intact.
  static String _stripEffortSuffix(String raw) {
    final idx = raw.lastIndexOf(':');
    if (idx <= 0 || idx == raw.length - 1) return raw;
    final suffix = raw.substring(idx + 1);
    if (codexEfforts.contains(suffix) || claudeEfforts.contains(suffix)) {
      return raw.substring(0, idx);
    }
    return raw;
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

  /// True when [modeString] appears verbatim in [allowedRawModels] — the
  /// selected profile's configured model list. Profile-configured models
  /// are provider-owned raw strings (e.g. `GLM-5`, `MiniMax-M3:high`) that
  /// belong to neither the Claude tier catalog nor the known Codex slugs,
  /// so flavor normalization would otherwise silently rewrite the user's
  /// pick to `default`.
  static bool _isAllowedRawModel(
    String modeString,
    List<String>? allowedRawModels,
  ) {
    if (allowedRawModels == null) return false;
    final needle = modeString.trim();
    if (needle.isEmpty) return false;
    for (final entry in allowedRawModels) {
      if (entry.trim() == needle) return true;
    }
    return false;
  }

  /// Normalizes a model selection so it is valid for the session flavor.
  ///
  /// [allowedRawModels] is the selected profile's configured model list
  /// (see [availableForProfile]); entries in it are valid selections for a
  /// Claude-compatible session even though they parse as unknown/provider
  /// strings. Codex sessions never offer profile models, so the allowlist
  /// is ignored for `codex`.
  static ChatModelMode normalizeForFlavor(
    ChatModelMode model,
    String? flavor, {
    List<String>? allowedRawModels,
  }) {
    final available = availableForFlavor(flavor);
    if (available.contains(model) || (flavor == 'codex' && model.isCodex)) {
      return model;
    }
    // Custom Claude models (e.g. `claude-opus-4-8`) aren't in the static
    // catalog but are still valid selections for a Claude session.
    if ((flavor == 'claude' || flavor == null) &&
        model.isClaude &&
        model.isCustom) {
      return model;
    }
    if (flavor != 'codex' &&
        isAllowedRawSelection(model.modeString, allowedRawModels)) {
      return model;
    }
    return defaultModel;
  }

  /// Normalize a stored raw model string for a session flavor while preserving
  /// provider-owned strings that the app cannot parse into picker options.
  ///
  /// [allowedRawModels] is the selected profile's configured model list;
  /// entries survive verbatim (including `:effort` suffixes, which would
  /// otherwise parse as Codex variants and be dropped on Claude sessions).
  static String normalizeRawForFlavor(
    String value,
    String? flavor, {
    bool preserveProviderOwned = false,
    List<String>? allowedRawModels,
  }) {
    final trimmed = value.trim();
    if (flavor == 'codex' &&
        !preserveProviderOwned &&
        !isKnownCodexModelString(trimmed)) {
      return defaultModel.modeString;
    }
    if (isAllowedRawSelection(trimmed, allowedRawModels)) {
      return trimmed;
    }
    final parsed = fromString(value);
    final normalized = normalizeForFlavor(parsed, flavor);
    final parsedFlavor = parsed.flavor;
    if (normalized.isDefault && parsedFlavor != null) {
      return normalized.modeString;
    }
    return value;
  }

  static bool isKnownCodexModelString(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == defaultModel.modeString) {
      return true;
    }
    final slug = trimmed.contains(':')
        ? trimmed.substring(0, trimmed.indexOf(':'))
        : trimmed;
    return slug.startsWith('gpt-') ||
        RegExp(r'^o\d').hasMatch(slug) ||
        isTokenPlanCodexModelSlug(slug);
  }

  static ChatModelMode _fromColonSelection(String raw) {
    final separator = raw.lastIndexOf(':');
    if (separator <= 0 || separator == raw.length - 1) {
      return ChatModelMode._(label: raw, modeString: raw);
    }
    final slug = raw.substring(0, separator);
    final effort = raw.substring(separator + 1);
    if (slug == 'opus' || slug == 'sonnet' || slug == 'fable') {
      return ChatModelMode.fromClaudeModel(
        tier: slug,
        displayName: switch (slug) {
          'opus' => 'Opus',
          'sonnet' => 'Sonnet',
          _ => 'Fable',
        },
        effort: effort,
      );
    }
    if (_isClaudeModelSlug(slug)) {
      return ChatModelMode.custom(slug: slug, effort: effort);
    }
    return ChatModelMode.fromCodexModel(
      slug: slug,
      displayName: _displayNameFromSlug(slug),
      effort: effort,
    );
  }

  static bool _isClaudeModelSlug(String slug) {
    return slug.startsWith('claude-') || slug.contains('/claude-');
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
