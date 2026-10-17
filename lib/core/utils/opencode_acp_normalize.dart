/// OpenCode ACP display aliases; the original arguments stay in wireInput.
library;

import 'grok_acp_normalize.dart';
import 'tool_input_extractor.dart';

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
  // Older CLI rows stored the shell command as the tool title and then
  // replaced that title with Bash, leaving the terminal card blank.
  // Recover it only for execute/bash, never from a read/edit title.
  final kindText = kind?.toString().trim().toLowerCase() ?? '';
  if (canonical == 'Bash' &&
      kindText == 'execute' &&
      name.isNotEmpty &&
      !_isGenericOpenCodeShellName(name) &&
      extractCommand(input) == null) {
    input['command'] = name;
  }
  return GrokToolDispatch(name: canonical, input: input);
}

bool _isGenericOpenCodeShellName(String name) {
  switch (name.trim().toLowerCase()) {
    case 'bash':
    case 'shell':
    case 'execute':
    case 'terminal':
      return true;
    default:
      return false;
  }
}
