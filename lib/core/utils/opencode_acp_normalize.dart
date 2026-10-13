/// OpenCode ACP display aliases; the original arguments stay in wireInput.
library;

import 'grok_acp_normalize.dart';

const opencodeToolNameAliases = {
  'read': 'Read',
  'bash': 'Bash',
  'edit': 'Edit',
  'write': 'Write',
  'grep': 'Grep',
  'glob': 'Glob',
  'list': 'LS',
  'webfetch': 'WebFetch',
  'task': 'Task',
  'todowrite': 'TodoWrite',
};

GrokToolDispatch normalizeOpenCodeToolCall(
  Object? rawName,
  Object? kind,
  Map<String, dynamic> rawInput,
) {
  final name = rawName?.toString().trim() ?? '';
  final canonical =
      opencodeToolNameAliases[name] ??
      switch (kind) {
        'read' => 'Read',
        'edit' => 'Edit',
        'execute' => 'Bash',
        'search' => 'Grep',
        'fetch' => 'WebFetch',
        _ => name.isEmpty ? 'tool' : name,
      };
  final input = normalizeGrokToolInput(rawInput);
  for (final alias in const {
    'oldString': 'old_string',
    'newString': 'new_string',
    'replaceAll': 'replace_all',
  }.entries) {
    if (rawInput.containsKey(alias.key)) {
      input.putIfAbsent(alias.value, () => rawInput[alias.key]);
    }
  }
  return GrokToolDispatch(name: canonical, input: input);
}
