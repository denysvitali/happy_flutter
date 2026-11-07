import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Search terms that surface [AccountSettingsSection] in the hub search.
const accountSettingsSearchTerms = [
  'account',
  'backup',
  'secret key',
  'restore',
  'devices',
  'link',
  'sign out',
  'log out',
  'logout',
];

/// The hub's single account entry: backup key, restore and devices behind
/// one row, then a destructive sign-out row.
class AccountSettingsSection extends StatelessWidget {
  const AccountSettingsSection({required this.onSignOut, super.key});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;

    return SettingsSection(
      title: l10n.settingsAccount,
      children: [
        SettingsNavRow(
          icon: Icons.key_outlined,
          title: l10n.settingsAccountDevices,
          subtitle: l10n.settingsAccountDevicesSubtitle,
          onTap: () => context.pushNamed('account'),
        ),
        SettingsRow(
          icon: Icons.logout,
          iconColor: cs.error,
          title: l10n.settingsSignOut,
          subtitle: l10n.settingsSignOutSubtitle,
          onTap: onSignOut,
          trailing: Icon(
            Icons.chevron_right,
            size: AppIconSize.md,
            color: cs.error.withValues(alpha: AppOpacity.half),
          ),
        ),
      ],
    );
  }
}
