import 'package:flutter/widgets.dart';

import '../i18n/app_localizations.dart';
import 'clipboard_utils.dart';
import 'snack.dart';

/// Copies [text] and tells the user what actually happened.
///
/// Oversized text is truncated by [setClipboardTextSafely]; a plain "Copied"
/// would hide that the clipboard holds only part of it. Failures and
/// truncation always surface a snack bar. Success surfaces [successMessage]
/// (default "Copied to clipboard") unless [announceSuccess] is false — for
/// buttons that already flip to a "Copied" state.
///
/// Returns the write result so callers can drive their own copied state from
/// `result.success`.
Future<ClipboardWriteResult> copyWithFeedback(
  BuildContext context,
  String text, {
  String? successMessage,
  bool announceSuccess = true,
  int maxBytes = defaultClipboardMaxBytes,
}) async {
  final result = await setClipboardTextSafely(text, maxBytes: maxBytes);
  if (!context.mounted) return result;
  final l10n = context.l10n;
  if (!result.success) {
    context.showSnack(
      l10n.textSelectionFailedToCopy,
      tone: SnackTone.error,
      replaceCurrent: true,
    );
  } else if (result.truncated) {
    context.showSnack(
      l10n.clipboardCopiedTruncated(
        result.charactersCopied,
        result.originalCharacters,
      ),
      replaceCurrent: true,
    );
  } else if (announceSuccess) {
    context.showSnack(
      successMessage ?? l10n.commonCopiedToClipboard,
      duration: const Duration(seconds: 2),
      replaceCurrent: true,
    );
  }
  return result;
}
