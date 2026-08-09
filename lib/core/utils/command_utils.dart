/// Removes the shell process used to transport a Codex terminal command.
///
/// The wrapper is an implementation detail of the agent runner; the command
/// inside it is the useful part to show in summaries and terminal cards.
String cleanShellCommand(String? raw) {
  if (raw == null) return '';
  var command = raw.trim();
  // Agent transports can stack shells. Only unwrap the known absolute-path
  // launchers; commands such as `sudo sh -c` retain their user-visible
  // privilege semantics.
  for (var depth = 0; depth < 3; depth++) {
    final unwrapped = _removeTransportWrapper(command);
    if (unwrapped == null) break;
    command = unwrapped.trim();
  }
  return command;
}

String? _removeTransportWrapper(String command) {
  const transportWrappers = [
    '/bin/sh -c',
    '/bin/sh -lc',
    '/bin/bash -c',
    '/bin/bash -lc',
    '/bin/zsh -c',
    '/bin/zsh -lc',
    '/usr/bin/sh -c',
    '/usr/bin/sh -lc',
    '/usr/bin/bash -c',
    '/usr/bin/bash -lc',
    '/usr/bin/zsh -c',
    '/usr/bin/zsh -lc',
  ];
  for (final wrapper in transportWrappers) {
    if (command == wrapper) return '';
    if (!command.startsWith(wrapper) ||
        command.length == wrapper.length ||
        !_isShellWhitespace(command[wrapper.length])) {
      continue;
    }

    final payload = command.substring(wrapper.length).trimLeft();
    if (payload.isEmpty || (payload[0] != '"' && payload[0] != "'")) {
      return payload;
    }

    final parsed = _parseShellWord(payload);
    if (!parsed.closed) return payload;
    return '${parsed.value}${payload.substring(parsed.end)}';
  }
  return null;
}

/// Decodes one shell word without expanding variables or substitutions.
///
/// Parsing adjacent quote segments is what turns transport-safe constructs
/// such as `"'$variable'"` back into a readable `"$variable"`.
({bool closed, int end, String value}) _parseShellWord(String input) {
  final output = StringBuffer();
  var quote = '';
  var started = false;
  var index = 0;

  while (index < input.length) {
    final char = input[index];
    if (quote.isEmpty) {
      if (_isShellWhitespace(char)) {
        if (started) break;
        index++;
        continue;
      }
      started = true;
      if (char == '"' || char == "'") {
        quote = char;
        index++;
        continue;
      }
      if (char == r'\') {
        if (index + 1 >= input.length) {
          output.write(char);
          index++;
          continue;
        }
        final next = input[index + 1];
        if (next != '\n') output.write(next);
        index += 2;
        continue;
      }
      output.write(char);
      index++;
      continue;
    }

    if (quote == "'") {
      if (char == "'") {
        quote = '';
      } else {
        output.write(char);
      }
      index++;
      continue;
    }

    if (char == '"') {
      quote = '';
      index++;
      continue;
    }
    if (char == r'\' && index + 1 < input.length) {
      final next = input[index + 1];
      if (next == '\n') {
        index += 2;
        continue;
      }
      if (next == '"' || next == r'\' || next == r'$' || next == '`') {
        output.write(next);
        index += 2;
        continue;
      }
    }
    output.write(char);
    index++;
  }

  return (closed: quote.isEmpty, end: index, value: output.toString());
}

bool _isShellWhitespace(String char) =>
    char == ' ' || char == '\t' || char == '\n' || char == '\r';
