import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/profile.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/safe_pop.dart';
import '../../core/widgets/network_avatar_image.dart';
import 'helpers/account_dialogs.dart';
import 'widgets/connected_accounts_section.dart';

/// Account management screen
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key, this.loadConnectedServices});

  final Future<List<ConnectedServiceInfo>> Function()? loadConnectedServices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.accountAccountSettings),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => safePop<void>(context),
        ),
      ),
      body: ListView(
        padding: AppScreenPadding.settings,
        children: [
          buildProfileSection(context, ref),
          const SizedBox(height: AppSpacing.xxl),
          buildBackupSection(context),
          const SizedBox(height: AppSpacing.xxl),
          buildRestoreSection(context),
          const SizedBox(height: AppSpacing.xxl),
          buildDevicesSection(context),
          const SizedBox(height: AppSpacing.xxl),
          buildServicesSection(context),
        ],
      ),
    );
  }

  Widget buildProfileSection(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileNotifierProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SettingsSection(
      title: context.l10n.accountProfile,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              if (profile?.avatarUrl != null)
                NetworkAvatarImage(
                  url: profile!.avatarUrl!,
                  size: 36,
                  fallback: SettingsIconContainer(
                    icon: Icons.person,
                    color: cs.primary,
                  ),
                )
              else
                SettingsIconContainer(icon: Icons.person, color: cs.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?.displayName ?? 'Loading...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      profile?.github?.email ?? 'Not loaded',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildBackupSection(BuildContext context) {
    return SettingsSection(
      title: context.l10n.accountBackupKey,
      children: [
        SettingsNavRow(
          icon: Icons.key,
          title: context.l10n.accountShowBackupKey,
          subtitle: context.l10n.accountShowBackupKeySubtitle,
          onTap: () => showBackupKeyDialog(context),
        ),
        SettingsNavRow(
          icon: Icons.content_copy,
          title: context.l10n.accountCopyBackupKey,
          subtitle: context.l10n.accountCopyToClipboard,
          onTap: () => copyBackupKeyToClipboard(context),
        ),
      ],
    );
  }

  Widget buildRestoreSection(BuildContext context) {
    return SettingsSection(
      title: context.l10n.accountRestore,
      children: [
        SettingsNavRow(
          icon: Icons.restore,
          title: context.l10n.accountRestoreAccount,
          subtitle: context.l10n.accountRestoreAccountSubtitle,
          onTap: () => context.push('/settings/account/restore'),
        ),
      ],
    );
  }

  Widget buildDevicesSection(BuildContext context) {
    return SettingsSection(
      title: context.l10n.accountDevices,
      children: [
        SettingsNavRow(
          icon: Icons.devices,
          title: context.l10n.accountLinkedDevices,
          subtitle: context.l10n.accountLinkedDevicesSubtitle,
          onTap: () => context.push('/settings/account/devices'),
        ),
        SettingsNavRow(
          icon: Icons.add_link,
          title: context.l10n.accountLinkNewDevice,
          subtitle: context.l10n.accountLinkNewDeviceSubtitle,
          onTap: () => context.push('/settings/account/link'),
        ),
      ],
    );
  }

  Widget buildServicesSection(BuildContext context) {
    return SettingsSection(
      title: context.l10n.accountConnectedServices,
      children: [ConnectedServicesLoader(loadServices: loadConnectedServices)],
    );
  }
}
