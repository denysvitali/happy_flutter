import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds a [Text] by its string ignoring case.
///
/// Section headers render their title as written (no forced uppercase), so a
/// test should not care whether the copy is "Backup key" or "BACKUP KEY".
Finder findTextIgnoreCase(String text) => find.byWidgetPredicate(
  (widget) =>
      widget is Text && widget.data?.toLowerCase() == text.toLowerCase(),
  description: 'Text "$text" (case-insensitive)',
);
