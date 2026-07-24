import 'package:flutter/material.dart';

/// Snack bar helpers.
///
/// Dozens of call sites spelled out the full
/// `ScaffoldMessenger.of(...).showSnackBar(SnackBar(content: Text(msg)))`
/// incantation. These extensions keep that a one-liner and give the
/// mounted-check a single place to live.
extension SnackBarContext on BuildContext {
  /// Shows a plain text snack bar on the nearest [ScaffoldMessenger].
  ///
  /// Callers that cross an `await` should either check `mounted` first or
  /// capture the messenger before awaiting — this helper reads the messenger
  /// at call time and does not guard for you.
  void showSnack(String message, {Duration? duration}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(content: Text(message), duration: duration ?? _defaultDuration),
    );
  }

  /// Shows a plain text snack bar only when this context is still mounted.
  ///
  /// The safe default after an `await`.
  void showSnackIfMounted(String message, {Duration? duration}) {
    if (!mounted) return;
    showSnack(message, duration: duration);
  }
}

/// Flutter's own `SnackBar` default, restated so [SnackBarContext.showSnack]
/// stays byte-identical to the inline calls it replaced.
const Duration _defaultDuration = Duration(milliseconds: 4000);
