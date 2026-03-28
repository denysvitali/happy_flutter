import 'package:flutter/material.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

/// Danger zone section with sign-out in a red-tinted card.
class DangerZone extends StatelessWidget {
  const DangerZone({required this.onSignOut, super.key});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return SettingsSection(
      title: l10n.settingsAccount,
      danger: true,
      description: l10n.settingsSignOutConfirm,
      children: [
        SettingsRow(
          icon: Icons.logout,
          iconColor: cs.error,
          title: l10n.settingsSignOut,
          subtitle: l10n.settingsAccountSubtitle,
          onTap: onSignOut,
          trailing: Icon(
            Icons.chevron_right,
            size: 20,
            color: cs.error.withValues(alpha: AppOpacity.half),
          ),
        ),
      ],
    );
  }
}
