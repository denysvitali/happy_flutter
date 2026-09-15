/// Grapheme-safe truncation for display text.
///
/// A Dart `String.substring` cuts UTF-16 code units. When the cut lands
/// between the two halves of a surrogate pair — an emoji, or any character
/// outside the BMP — the result contains a lone surrogate. Flutter's text
/// layout rejects that outright:
///
///   ArgumentError: Invalid argument(s): string is not well-formed UTF-16
///
/// which surfaces as a paragraph-layout crash rather than a bad glyph
/// (GlitchTip 8777/8779, build 279300: a session preview cut mid-emoji took
/// down the home route). Slicing on grapheme-cluster boundaries cannot
/// produce a lone surrogate, because a surrogate pair is a single grapheme.
///
/// Use these for any text that came off the wire or out of a controller.
/// Fixed-offset `substring` stays fine for identifiers, hex, paths and other
/// ASCII-only data.
library;

import 'package:characters/characters.dart';

/// Returns [text] limited to its first [maxGraphemes] user-perceived
/// characters, with [ellipsis] appended when anything was dropped.
///
/// The ellipsis is not counted against [maxGraphemes], so a caller that
/// budgets a fixed width should account for it (it defaults to one
/// character wide in every font the app ships).
String truncateGraphemes(
  String text,
  int maxGraphemes, {
  String ellipsis = '…',
}) {
  if (maxGraphemes <= 0) return '';
  final characters = text.characters;
  if (characters.length <= maxGraphemes) return text;
  return '${characters.take(maxGraphemes)}$ellipsis';
}

/// Returns the last [maxGraphemes] user-perceived characters of [text].
///
/// The mirror of [truncateGraphemes] for bounded-tail rendering (streaming
/// code blocks). Trimming to a code-unit offset is unsafe at the *start* of
/// the tail for the same reason as above — a low surrogate left behind with
/// no high surrogate is equally malformed.
String tailGraphemes(String text, int maxGraphemes) {
  if (maxGraphemes <= 0) return '';
  final characters = text.characters;
  if (characters.length <= maxGraphemes) return text;
  return characters.skip(characters.length - maxGraphemes).toString();
}
