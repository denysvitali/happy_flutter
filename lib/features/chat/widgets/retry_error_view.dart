import 'package:flutter/material.dart';

import '../../../core/components/app_error_state.dart';
import '../../../core/i18n/app_localizations.dart';

/// A centered error view with a retry button, shown when messages
/// fail to load.
///
/// Thin wrapper over [AppErrorState] so chat keeps a stable type for
/// tests while sharing design-system chrome with the rest of the app.
class RetryErrorView extends StatelessWidget {
  const RetryErrorView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppErrorState(
      key: const ValueKey('retry'),
      message: l10n.chatFailedToLoadMessages,
      onRetry: onRetry,
      retryLabel: l10n.commonRetry,
    );
  }
}
