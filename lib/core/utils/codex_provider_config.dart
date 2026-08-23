import 'dart:convert';

import '../models/settings.dart';

/// Transport keys used to pass Codex provider definitions through the daemon
/// spawn environment. The values contain no credentials; [CodexProviderConfig]
/// points Codex at the separate environment variable that holds a key.
const codexProvidersEnvironmentKey = 'HAPPY_CODEX_PROVIDERS';
const codexModelProviderEnvironmentKey = 'HAPPY_CODEX_MODEL_PROVIDER';

String encodeCodexProviders(List<CodexProviderConfig> providers) => jsonEncode(
  providers.map((provider) => provider.toJson()).toList(growable: false),
);
