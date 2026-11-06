import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Semantic appearance of a snack bar.
///
/// [neutral] keeps the theme's default snack bar (confirmations, hints,
/// "copied"). [error] uses the same `errorContainer` / `onErrorContainer`
/// tokens and leading error icon as `ErrorSnackbarManager`, so every failure
/// toast reads the same way and is recognisable without relying on color.
enum SnackTone { neutral, error }

/// Snack bar helpers.
///
/// Dozens of call sites spelled out the full
/// `ScaffoldMessenger.of(...).showSnackBar(SnackBar(content: Text(msg)))`
/// incantation. These extensions keep that a one-liner, give the
/// mounted-check a single place to live, and own the error styling.
extension SnackBarContext on BuildContext {
  /// Shows a text snack bar on the nearest [ScaffoldMessenger].
  ///
  /// Callers that cross an `await` should either check `mounted` first or
  /// capture the messenger before awaiting (and use
  /// [SnackBarMessenger.showSnack]) — this helper reads the messenger at
  /// call time and does not guard for you.
  ///
  /// See [SnackBarMessenger.showSnack] for [tone], [action] and
  /// [replaceCurrent].
  void showSnack(
    String message, {
    Duration? duration,
    SnackTone tone = SnackTone.neutral,
    SnackBarAction? action,
    bool replaceCurrent = false,
  }) {
    ScaffoldMessenger.of(this).showSnack(
      message,
      duration: duration,
      tone: tone,
      action: action,
      replaceCurrent: replaceCurrent,
    );
  }

  /// Shows a text snack bar only when this context is still mounted.
  ///
  /// The safe default after an `await`.
  void showSnackIfMounted(
    String message, {
    Duration? duration,
    SnackTone tone = SnackTone.neutral,
    SnackBarAction? action,
    bool replaceCurrent = false,
  }) {
    if (!mounted) return;
    showSnack(
      message,
      duration: duration,
      tone: tone,
      action: action,
      replaceCurrent: replaceCurrent,
    );
  }
}

/// The same helpers for a [ScaffoldMessengerState] captured before an async
/// gap (or before the caller's route is popped).
extension SnackBarMessenger on ScaffoldMessengerState {
  /// Shows a text snack bar styled for [tone].
  ///
  /// [action] (Undo/Retry) is kept as-is; on [SnackTone.error] its label
  /// defaults to `onErrorContainer` so it stays legible on the container.
  ///
  /// [replaceCurrent] hides the visible snack bar first instead of queueing
  /// behind it — for feedback that can repeat quickly (copy, "press back
  /// again", setting hints) where a backlog of identical toasts is
  /// confusing.
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnack(
    String message, {
    Duration? duration,
    SnackTone tone = SnackTone.neutral,
    SnackBarAction? action,
    bool replaceCurrent = false,
  }) {
    if (replaceCurrent) hideCurrentSnackBar();
    return showSnackBar(
      buildToneSnackBar(
        context,
        message,
        duration: duration,
        tone: tone,
        action: action,
      ),
    );
  }
}

/// Builds the [SnackBar] the helpers show. Exposed for tests and for the rare
/// caller that must hand a prebuilt [SnackBar] to another API.
SnackBar buildToneSnackBar(
  BuildContext context,
  String message, {
  Duration? duration,
  SnackTone tone = SnackTone.neutral,
  SnackBarAction? action,
}) {
  final effectiveDuration = duration ?? _defaultDuration;
  switch (tone) {
    case SnackTone.neutral:
      return SnackBar(
        content: Text(message),
        duration: effectiveDuration,
        action: action,
      );
    case SnackTone.error:
      final cs = Theme.of(context).colorScheme;
      return SnackBar(
        backgroundColor: cs.errorContainer,
        duration: effectiveDuration,
        action: action == null
            ? null
            : SnackBarAction(
                label: action.label,
                onPressed: action.onPressed,
                textColor: action.textColor ?? cs.onErrorContainer,
                disabledTextColor: action.disabledTextColor,
                backgroundColor: action.backgroundColor,
                disabledBackgroundColor: action.disabledBackgroundColor,
              ),
        content: Row(
          children: [
            Icon(Icons.error_outline, color: cs.onErrorContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: cs.onErrorContainer),
              ),
            ),
          ],
        ),
      );
  }
}

/// Flutter's own `SnackBar` default, restated so [SnackBarContext.showSnack]
/// stays byte-identical to the inline calls it replaced.
const Duration _defaultDuration = Duration(milliseconds: 4000);
