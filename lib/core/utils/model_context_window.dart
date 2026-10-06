import '../models/settings.dart';

/// Token budgets a profile can request for one model.
///
/// [extendedContextWindowTokens] is also the Claude Code `[1m]` model suffix.
/// Every positive choice, including the smaller sizes, is passed to the
/// spawned process as [claudeCodeMaxContextTokensEnv]. The usage indicator
/// reads the same stored value.
const List<int> selectableContextWindows = <int>[
  32000,
  128000,
  200000,
  256000,
  extendedContextWindowTokens,
];

/// Claude Code env var that overrides the context window the CLI assumes for
/// the active model. Required when a profile routes through
/// `ANTHROPIC_BASE_URL` to a model whose window is not the size Claude Code
/// built in for that name. The value is a plain integer (`200000`, not
/// `200k`).
const String claudeCodeMaxContextTokensEnv = 'CLAUDE_CODE_MAX_CONTEXT_TOKENS';

/// A model id with the context window its profile requests, or null to use
/// the model's own default.
class ModelContextChoice {
  const ModelContextChoice({required this.model, this.contextWindow});

  final String model;
  final int? contextWindow;
}

/// Parse one stored model entry.
///
/// Entries are plain ids (`opencode/x-preview-f-free`) or an id plus a
/// window (`id@1000000`). A trailing `@` with no number, or a non-numeric
/// suffix, stays part of the id so an unusual model name is never truncated.
ModelContextChoice parseModelContextChoice(String raw) {
  final trimmed = raw.trim();
  final at = trimmed.lastIndexOf('@');
  if (at <= 0 || at == trimmed.length - 1) {
    return ModelContextChoice(model: trimmed);
  }
  final window = int.tryParse(trimmed.substring(at + 1));
  if (window == null || window <= 0) {
    return ModelContextChoice(model: trimmed);
  }
  return ModelContextChoice(
    model: trimmed.substring(0, at),
    contextWindow: window,
  );
}

/// Serialize a model entry. A null window stores the bare id, which is what
/// every profile saved before per-model windows existed.
String encodeModelContextChoice(ModelContextChoice choice) {
  final model = choice.model.trim();
  final window = choice.contextWindow;
  if (window == null || window <= 0) return model;
  return '$model@$window';
}

/// The window a profile requests for [model], or null for the model's own
/// default.
///
/// A per-model `@window` entry wins, and a bare entry means "no override"
/// even when the profile still carries a profile-wide window. The profile
/// window only covers models the list does not name, so a profile saved
/// before per-model windows keeps the 1M budget it already requested.
/// Matching ignores a trailing `[1m]` and a `:effort` suffix: the picker
/// stores the base id, while sends append both.
int? contextWindowForModel({
  required AIBackendProfile? profile,
  required String? model,
}) {
  if (profile == null) return null;
  final key = modelContextKey(model);
  if (key != null) {
    for (final entry in profile.models) {
      final choice = parseModelContextChoice(entry);
      if (modelContextKey(choice.model) == key) {
        return choice.contextWindow;
      }
    }
  }
  return profile.contextWindow;
}

/// Identity used to match a selected model against a profile's model list.
///
/// `provider/model:high[1m]` and `provider/model` are the same model.
String? modelContextKey(String? raw) {
  if (raw == null) return null;
  var value = raw.trim();
  if (value.endsWith('[1m]')) {
    value = value.substring(0, value.length - '[1m]'.length);
  }
  final colon = value.lastIndexOf(':');
  if (colon > 0) value = value.substring(0, colon);
  value = value.trim();
  return value.isEmpty ? null : value;
}

/// The context window assumed for [model] when nobody configured one.
///
/// Only models whose window is part of the model id (or a stable vendor
/// default) get a guess. Everything else returns null and the caller keeps
/// the provider default, which is the safe choice for a routed catalog that
/// changes without notice.
int? defaultContextWindowForModel(String? model) {
  final key = modelContextKey(model);
  if (key == null) return null;
  final leaf = key.split('/').last.toLowerCase();

  if (leaf.endsWith('[1m]')) return extendedContextWindowTokens;

  // Claude's 1M-context tier is a distinct model id; the plain ids stay on
  // the 200k window unless the profile opts into `[1m]`.
  if (leaf.contains('claude-') &&
      (leaf.contains('1m') || leaf.contains('context-1m'))) {
    return extendedContextWindowTokens;
  }

  // Grok 4.5/4.6/4.7 ship a 500k window. The older grok-4 ids (grok-4,
  // grok-4-0709) are 256k, so the match stops at the dotted minor version.
  if (RegExp(r'^grok-4\.[5-9]').hasMatch(leaf)) return 500000;

  // Gemini 2.5/3 Pro and Flash are 1M. The `gemini-1.5` and `gemini-2.0`
  // lines are not, and a bare "gemini" leaf must not be assumed.
  if (RegExp(r'^gemini-(2\.5|3)').hasMatch(leaf)) {
    return extendedContextWindowTokens;
  }

  if (leaf.startsWith('gpt-4.1') || leaf.startsWith('gpt-5')) {
    return extendedContextWindowTokens;
  }
  if (leaf.startsWith('o3') || leaf.startsWith('o4')) return 200000;

  // MiniMax-M3 and the current Kimi code line are 200k. Older M2/M2.x ids
  // are larger, so only the ids that advertise 200k are pinned.
  if (leaf.startsWith('minimax-m3') || leaf.startsWith('kimi-k2')) {
    return 200000;
  }

  return null;
}

/// The window the usage indicator should measure [model] against.
///
/// A profile choice wins, then a known model default, then null so the
/// indicator keeps its own conservative budget.
int? effectiveContextWindow({
  required AIBackendProfile? profile,
  required String? model,
}) {
  final chosen = contextWindowForModel(profile: profile, model: model);
  if (chosen != null && chosen > 0) return chosen;
  return defaultContextWindowForModel(model);
}

/// The window a Claude spawn should tell the process about.
///
/// Only an explicit profile choice is sent. A known model default (Grok's
/// 500k, Gemini's 1M) sizes the usage indicator and must not invent an
/// override the user never stored. [model] may be a picker id, a `:effort`
/// selection, or null when the session launches on the profile default.
int? contextWindowOverrideForSpawn({
  required AIBackendProfile? profile,
  required String? model,
}) {
  if (profile == null) return null;
  final selected = contextWindowForModel(profile: profile, model: model);
  if (selected != null) return selected > 0 ? selected : null;
  // `default` and the daemon aliases are not ids in the model list, so the
  // profile-wide window above already applies. A concrete id that the list
  // names without `@tokens` is an opt-out and stays null.
  if (model == null || model.trim().isEmpty || model.trim() == 'default') {
    final fallback = profile.contextWindow;
    if (fallback != null && fallback > 0) return fallback;
  }
  return null;
}

/// Writes [claudeCodeMaxContextTokensEnv] when [profile] explicitly requests a
/// window for [model].
///
/// No choice leaves the map untouched, so a variable the profile stored itself
/// survives and an unconfigured model does not inherit a guessed window.
/// Codex and other non-Claude agents do not read this knob.
Map<String, String> applyContextWindowToSpawnEnv(
  Map<String, String> envVars, {
  required String? agent,
  required AIBackendProfile? profile,
  required String? model,
}) {
  if (agent != null && agent != 'claude') return envVars;
  final window = contextWindowOverrideForSpawn(profile: profile, model: model);
  if (window == null) return envVars;
  final encoded = window.toString();
  if (envVars[claudeCodeMaxContextTokensEnv] == encoded) return envVars;
  return <String, String>{...envVars, claudeCodeMaxContextTokensEnv: encoded};
}
