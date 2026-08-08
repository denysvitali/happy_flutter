/// Removes the shell process used to transport a Codex terminal command.
///
/// The wrapper is an implementation detail of the agent runner; the command
/// inside it is the useful part to show in summaries and terminal cards.
String cleanShellCommand(String? raw) {
  if (raw == null) return '';
  var command = raw.trim();
  const transportWrappers = [
    '/bin/sh -lc',
    '/bin/bash -lc',
    '/usr/bin/sh -lc',
    '/usr/bin/bash -lc',
  ];
  for (final wrapper in transportWrappers) {
    if (command == wrapper) return '';
    if (command.startsWith('$wrapper ')) {
      command = command.substring(wrapper.length).trim();
      command = _stripWrappedQuotes(command);
      break;
    }
  }
  return command;
}

String _stripWrappedQuotes(String value) {
  if (value.length < 2) return value;
  final first = value[0];
  final last = value[value.length - 1];
  if (first != last || (first != '"' && first != "'")) {
    return value;
  }
  var unwrapped = value.substring(1, value.length - 1);
  if (first == '"') {
    unwrapped = unwrapped.replaceAll(r'\"', '"');
    unwrapped = unwrapped.replaceAll(r'\\', r'\');
  }
  return unwrapped;
}
