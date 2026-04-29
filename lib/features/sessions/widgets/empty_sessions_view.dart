import 'package:flutter/material.dart';

import '../../../core/components/app_empty_state.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import 'new_session_dialog.dart';

/// Empty sessions view — clean, minimal design.
class EmptySessionsView extends StatelessWidget {
  const EmptySessionsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppEmptyState(
      icon: Icons.computer_outlined,
      title: l10n.sessionNoSessionsYet,
      subtitle:
          '${l10n.emptyMainScreenInstallCli}\n'
          '${l10n.emptyMainScreenRunIt}\n'
          '${l10n.emptyMainScreenScanQrCode}',
      action: FilledButton.icon(
        onPressed: () => _showNewSessionDialog(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.sessionNewSession),
        style: FilledButton.styleFrom(
          minimumSize: const Size(160, AppTouchTarget.min),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }

  Future<void> _showNewSessionDialog(BuildContext context) async {
    await showDialog<String>(
      context: context,
      builder: (context) => const NewSessionDialog(),
    );
  }
}
