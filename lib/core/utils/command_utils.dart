String cleanShellCommand(String? raw) {
  if (raw == null) return '';
  var command = raw.trim();
  const prefix = '/bin/bash -lc ';
  if (command.startsWith(prefix)) {
    command = command.substring(prefix.length).trim();
    command = _stripWrappedQuotes(command);
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
