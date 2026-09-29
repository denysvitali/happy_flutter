/// Removes the display wrappers around reasoning supplied by the parser.
/// Shared by list filtering and the thinking widget so hidden reasoning
/// never leaves a padded row in the transcript.
String cleanThinkingContent(String raw) {
  var text = raw.replaceFirst(_thinkingPrefix, '').trim();
  if (text.startsWith('*') && text.endsWith('*') && text.length > 2) {
    text = text.substring(1, text.length - 1).trim();
  }
  return text == '**' ? '' : text;
}

final _thinkingPrefix = RegExp(r'^\*Thinking\.\.\.\*\s*\n*');
