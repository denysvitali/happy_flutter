/// Heuristic for deciding whether an environment variable holds a
/// secret and should therefore be masked in the UI by default.
///
/// Only genuine credentials (API keys, tokens, passwords, …) are
/// considered secret — configuration values such as base URLs, model
/// names, timeouts, and feature flags stay visible so the profile
/// editor remains readable.
library;

import '../models/settings.dart';

/// Word segments that strongly indicate a secret without requiring
/// surrounding context.
///
/// `TOKEN`/`KEY` are deliberately absent: they are only secret as a
/// trailing suffix (`GITHUB_TOKEN`, `API_KEY`) — handled by
/// [_secretSuffixes] — not mid-name (`MAX_TOKEN_COUNT`, `KEYSTONE_URL`).
const Set<String> _secretSegments = {
  'SECRET',
  'PASSWORD',
  'PASSWD',
  'PWD',
  'PASS',
  'CREDENTIAL',
  'CREDENTIALS',
};

/// Suffixes that mark a name as secret even when written without a
/// separator (e.g. `APIKEY`, `ACCESSTOKEN`).
const List<String> _secretSuffixes = ['KEY', 'TOKEN', 'SECRET', 'PASSWORD'];

/// Prefixes that typically pair with `KEY` or `TOKEN` to indicate a
/// credential value (e.g. `API_KEY`, `AUTH_TOKEN`).
const Set<String> _secretPrefixSegments = {
  'API',
  'ACCESS',
  'AUTH',
  'PRIVATE',
  'CLIENT',
  'SESSION',
  'SIGNING',
  'ENCRYPTION',
  'JWT',
  'BEARER',
  'REFRESH',
  'OAUTH',
  'ANTHROPIC',
  'OPENAI',
  'AZURE',
  'GEMINI',
  'OPENROUTER',
};

/// Returns true when [name] looks like it holds a credential.
///
/// Matching is case-insensitive and works on non-alphanumeric
/// segments (`ANTHROPIC_AUTH_TOKEN` → AUTH/TOKEN) plus common
/// unseparated suffixes (`APIKEY`). Plain configuration names such as
/// `ANTHROPIC_BASE_URL`, `ANTHROPIC_MODEL`, `API_TIMEOUT_MS`, or
/// `AZURE_OPENAI_API_VERSION` return false.
bool isSecretEnvName(String name) {
  final upper = name.trim().toUpperCase();
  if (upper.isEmpty) return false;

  final segments = upper
      .split(RegExp('[^A-Z0-9]+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (segments.isEmpty) return false;

  for (final segment in segments) {
    if (_secretSegments.contains(segment)) return true;
  }

  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    if ((segment == 'KEY' || segment == 'TOKEN') &&
        _hasSecretPrefix(segments, i)) {
      return true;
    }
  }

  for (final suffix in _secretSuffixes) {
    // Guard against mid-word false positives: a suffix match must
    // leave a non-empty stem (e.g. `MONKEY` ends with `KEY` but is
    // not a credential name; `APIKEY` is).
    if (upper.length > suffix.length && upper.endsWith(suffix)) {
      final stem = upper.substring(0, upper.length - suffix.length);
      if (_looksLikeEnvName(stem)) {
        return true;
      }
    }
  }

  return false;
}

bool _hasSecretPrefix(List<String> segments, int index) {
  if (index == 0 || index != segments.length - 1) return false;
  final prefix = segments[index - 1];
  return _secretPrefixSegments.contains(prefix) || _looksLikeApiScope(prefix);
}

bool _looksLikeApiScope(String prefix) {
  if (prefix.length < 3) return false;
  return prefix.endsWith('API') || prefix.endsWith('AUTH');
}

/// Suggests a profile name from imported environment variables.
///
/// Prefers well-known model variables and otherwise falls back to the
/// first *non-secret* variable — never a credential, so a pasted
/// `ANTHROPIC_AUTH_TOKEN=sk-…` can not leak into the profile name
/// (which is rendered unmasked across the app). Returns null when no
/// usable value exists.
String? suggestProfileName(List<EnvironmentVariable> envVars) {
  const modelVarNames = {
    'ANTHROPIC_MODEL',
    'ANTHROPIC_DEFAULT_OPUS_MODEL',
    'OPENAI_MODEL',
  };
  EnvironmentVariable? candidate;
  for (final env in envVars) {
    if (modelVarNames.contains(env.name) && env.value.isNotEmpty) {
      candidate = env;
      break;
    }
  }
  if (candidate == null) {
    for (final env in envVars) {
      if (!isSecretEnvName(env.name) && env.value.isNotEmpty) {
        candidate = env;
        break;
      }
    }
  }
  final value = candidate?.value;
  if (value == null || value.isEmpty) return null;
  final parts = value.split('/');
  return parts.length > 1 ? parts.last : value;
}

/// A stem "looks like" an env name when it is all caps/digits/underscore
/// and does not end in a common word that makes the suffix coincidental
/// (e.g. `MONKEY`, `TURKEY`, `HOCKEY`).
bool _looksLikeEnvName(String stem) {
  if (!RegExp(r'^[A-Z0-9_]+$').hasMatch(stem)) return false;
  if (stem.endsWith('_')) return true;
  // Suffix joined directly to a word: require the stem to contain a
  // separator or be a well-known credential prefix (API, ACCESS,
  // AUTH, SESSION, PRIVATE, SECRET, CLIENT, APP, USER, MASTER).
  if (stem.contains('_')) return true;
  const prefixes = {
    'API',
    'ACCESS',
    'AUTH',
    'SESSION',
    'PRIVATE',
    'SECRET',
    'CLIENT',
    'APP',
    'USER',
    'MASTER',
    'SERVICE',
    'SIGNING',
    'ENCRYPTION',
  };
  return prefixes.contains(stem);
}
