import 'package:flutter/material.dart';

import '../../../core/theme/app_text.dart';

/// Sessions-list names for the shared [AppText] roles.
///
/// Kept so Mission Control call sites read the same; the styles themselves
/// live in [AppText] and are shared with every other row in the app.
abstract final class MissionType {
  /// Row names — see [AppText.title].
  static TextStyle title(ThemeData theme, Color color) =>
      AppText.title(theme, color);

  /// Secondary detail under a row name — see [AppText.secondary].
  static TextStyle meta(ThemeData theme, Color color) =>
      AppText.secondary(theme, color);

  /// Section headers and chip labels — see [AppText.label].
  static TextStyle label(ThemeData theme, Color color) =>
      AppText.label(theme, color);

  /// Counts and pills — see [AppText.badge].
  static TextStyle badge(ThemeData theme, Color color) =>
      AppText.badge(theme, color);
}
