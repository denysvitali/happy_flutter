import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/api/github_api.dart';
import '../../core/api/services_api.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/machine.dart';
import '../../core/models/profile.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/certificate_provider.dart';
import '../../core/services/server_config.dart';
import '../../core/theme/app_tokens.dart';

// ─── Settings Screen ─────────────────────────────────────────────────────────

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final profile = ref.watch(profileNotifierProvider);
    final machines = ref.watch(machinesNotifierProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          _ProfileHeader(profile: profile),
          const SizedBox(height: AppSpacing.xl),
          _buildAppearanceSection(context, settings, ref),
          const SizedBox(height: AppSpacing.lg),
          _buildBehaviorSection(context, settings, ref),
          const SizedBox(height: AppSpacing.lg),
          _buildVoiceSection(context, settings, ref),
          const SizedBox(height: AppSpacing.lg),
          _buildConnectedAccountsSection(context, ref, profile),
          const SizedBox(height: AppSpacing.lg),
          _buildAIProfilesSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildUsageSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildFeaturesSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildSocialSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildMachinesSection(context, machines),
          if (machines.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          _buildAccountSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildCertificatesSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildServerSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildDeveloperSection(context, settings),
          const SizedBox(height: AppSpacing.lg),
          _buildAboutSection(context),
          const SizedBox(height: AppSpacing.xl),
          const _AccountSection(),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildConnectedAccountsSection(
    BuildContext context,
    WidgetRef ref,
    Profile? profile,
  ) {
    final github = profile?.github;
    final claudeConnected =
        profile?.connectedServices.contains('anthropic') ?? false;

    return SettingsSection(
      title: 'Connected Accounts',
      children: [
        _SettingsNavRow(
          icon: Icons.smart_toy_outlined,
          title: 'Claude Code',
          subtitle: claudeConnected ? 'Connected' : 'Not connected',
          onTap: () async {
            if (claudeConnected) {
              try {
                await ServicesApi().disconnectClaude();
                await ref
                    .read(profileNotifierProvider.notifier)
                    .refreshFromSync();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Claude disconnected')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to disconnect: $error')),
                );
              }
            } else {
              unawaited(context.pushNamed('account'));
            }
          },
        ),
        _SettingsNavRow(
          icon: Icons.code,
          title: 'GitHub',
          subtitle: github != null
              ? 'Connected as @${github.login}'
              : 'Not connected',
          onTap: () async {
            if (github != null) {
              try {
                await GitHubApi().disconnectGitHub();
                await ref
                    .read(profileNotifierProvider.notifier)
                    .refreshFromSync();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('GitHub disconnected')),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to disconnect: $error')),
                );
              }
            } else {
              try {
                final params = await GitHubApi().getOAuthParams();
                final uri = Uri.parse(params.url);
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to start OAuth: $error')),
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(
    BuildContext context,
    Settings settings,
    WidgetRef ref,
  ) {
    final l10n = AppLocalizations.of(context);
    final themeModeLabel = switch (settings.themeMode) {
      'light' => l10n.appearanceThemeLight,
      'dark' => l10n.appearanceThemeDark,
      'adaptive' => l10n.appearanceThemeAdaptive,
      _ => l10n.appearanceThemeAdaptive,
    };

    return SettingsSection(
      title: l10n.settingsAppearance,
      children: [
        _SettingsNavRow(
          icon: Icons.palette,
          title: l10n.appearanceTheme,
          subtitle: themeModeLabel,
          onTap: () => context.pushNamed('theme'),
        ),
        _SettingsNavRow(
          icon: Icons.language,
          title: l10n.settingsLanguage,
          subtitle: settings.locale.isEmpty
              ? l10n.settingsLanguageAutomatic
              : _getLocaleDisplayName(settings.locale),
          onTap: () => context.pushNamed('language'),
        ),
        _SettingsToggleRow(
          icon: Icons.emoji_emotions_outlined,
          title: l10n.settingsShowFlavorIcons,
          subtitle: l10n.settingsShowFlavorIconsSubtitle,
          value: settings.showFlavorIcons,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('showFlavorIcons', value),
        ),
        _SettingsNavRow(
          icon: Icons.account_circle_outlined,
          title: l10n.settingsAvatarStyle,
          subtitle: settings.avatarStyle,
          onTap: () => showAvatarStyleDialog(context, settings, ref),
        ),
      ],
    );
  }

  String _getLocaleDisplayName(String localeString) {
    if (localeString.isEmpty) return '';
    final parts = localeString.split('_');
    if (parts.length == 2) {
      final first = '${parts[0][0].toUpperCase()}${parts[0].substring(1)}';
      return '$first (${parts[1]})';
    }
    return '${parts[0][0].toUpperCase()}${parts[0].substring(1)}';
  }

  Widget _buildBehaviorSection(
    BuildContext context,
    Settings settings,
    WidgetRef ref,
  ) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsBehavior,
      children: [
        _SettingsToggleRow(
          icon: Icons.open_in_new_outlined,
          title: l10n.settingsViewInline,
          subtitle: l10n.settingsViewInlineSubtitle,
          value: settings.viewInline,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('viewInline', value),
        ),
        _SettingsToggleRow(
          icon: Icons.check_box_outlined,
          title: l10n.settingsExpandTodos,
          value: settings.expandTodos,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('expandTodos', value),
        ),
        _SettingsToggleRow(
          icon: Icons.format_list_numbered,
          title: l10n.settingsShowLineNumbers,
          value: settings.showLineNumbers,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('showLineNumbers', value),
        ),
        _SettingsToggleRow(
          icon: Icons.wrap_text,
          title: l10n.settingsWrapLinesInDiffs,
          value: settings.wrapLinesInDiffs,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('wrapLinesInDiffs', value),
        ),
      ],
    );
  }

  Widget _buildVoiceSection(
    BuildContext context,
    Settings settings,
    WidgetRef ref,
  ) {
    return SettingsSection(
      title: 'Voice',
      children: [
        _SettingsToggleRow(
          icon: Icons.volume_up_outlined,
          title: 'Text-to-Speech',
          subtitle: 'Read assistant messages aloud',
          value: settings.ttsEnabled,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('ttsEnabled', value),
        ),
        _SettingsNavRow(
          icon: Icons.record_voice_over,
          title: 'Voice Settings',
          subtitle: 'Configure voice assistant',
          onTap: () => context.pushNamed('voice'),
        ),
      ],
    );
  }

  Widget _buildAIProfilesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsProfiles,
      children: [
        _SettingsNavRow(
          icon: Icons.account_tree,
          title: l10n.settingsProfiles,
          subtitle: l10n.settingsProfilesSubtitle,
          onTap: () => context.pushNamed('profiles'),
        ),
      ],
    );
  }

  Widget _buildUsageSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsUsage,
      children: [
        _SettingsNavRow(
          icon: Icons.analytics,
          title: l10n.settingsUsage,
          subtitle: l10n.settingsUsageSubtitle,
          onTap: () => context.pushNamed('usage'),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsFeatures,
      children: [
        _SettingsNavRow(
          icon: Icons.science,
          title: l10n.featuresExperiments,
          subtitle: l10n.featuresExperimentsDesc,
          onTap: () => context.pushNamed('features'),
        ),
      ],
    );
  }

  Widget _buildSocialSection(BuildContext context) {
    return SettingsSection(
      title: 'Social',
      children: [
        _SettingsNavRow(
          icon: Icons.person_add_alt_1,
          title: 'Find Friends',
          subtitle: 'Search and send friend requests',
          onTap: () => context.pushNamed('friends-search'),
        ),
        _SettingsNavRow(
          icon: Icons.inbox_outlined,
          title: 'Open Inbox',
          subtitle: 'View updates and requests',
          onTap: () => context.pushNamed('inbox'),
        ),
      ],
    );
  }

  Widget _buildMachinesSection(
    BuildContext context,
    Map<String, Machine> machines,
  ) {
    if (machines.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final machineList = machines.values.toList()
      ..sort((a, b) {
        if (a.active == b.active) {
          return b.activeAt.compareTo(a.activeAt);
        }
        return a.active ? -1 : 1;
      });

    return SettingsSection(
      title: 'Machines',
      children: machineList
          .map((machine) {
            final metadata = machine.metadata;
            final title = metadata?.displayName ?? metadata?.host ?? machine.id;
            final subtitle =
                '${metadata?.platform ?? 'unknown'}'
                ' • ${machine.active ? 'Online' : 'Offline'}';
            return _SettingsRow(
              icon: Icons.computer_outlined,
              iconColor: machine.active
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.4),
              title: title,
              subtitle: subtitle,
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildDeveloperSection(BuildContext context, Settings settings) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsDeveloper,
      children: [
        _SettingsNavRow(
          icon: Icons.build,
          title: 'Developer Options',
          subtitle: settings.developerModeEnabled
              ? 'Enabled'
              : 'Tap 10 times to enable',
          onTap: () => context.pushNamed('developer'),
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsAccount,
      children: [
        _SettingsNavRow(
          icon: Icons.person,
          title: l10n.accountAccountSettings,
          subtitle: 'Backup key, devices, services',
          onTap: () => context.pushNamed('account'),
        ),
      ],
    );
  }

  Widget _buildCertificatesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsCertificates,
      children: [
        FutureBuilder<bool>(
          future: Future.value(CertificateProvider().hasUserCertificates()),
          builder: (context, snapshot) {
            final hasCerts = snapshot.data ?? false;
            return _SettingsRow(
              icon: hasCerts ? Icons.verified_user : Icons.info_outline,
              iconColor: hasCerts
                  ? Theme.of(context).colorScheme.primary
                  : null,
              title: l10n.settingsUserCaCertificates,
              subtitle: hasCerts
                  ? l10n.settingsUserCertificatesInstalled
                  : l10n.settingsNoUserCertificates,
            );
          },
        ),
      ],
    );
  }

  Widget _buildServerSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsServer,
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _getServerInfo(),
          builder: (context, snapshot) {
            final url = snapshot.data?['url'] as String? ?? 'Loading...';
            final isCustom = snapshot.data?['isCustom'] as bool? ?? false;

            return _SettingsRow(
              icon: isCustom ? Icons.edit : Icons.cloud_outlined,
              title: l10n.settingsServerUrl,
              subtitle: url,
              trailing: Icon(
                isCustom ? Icons.edit : Icons.chevron_right,
                size: 20,
                color: isCustom
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              onTap: () => showServerUrlDialog(context, url),
            );
          },
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getServerInfo() async {
    final url = getServerUrl();
    final isCustom = isUsingCustomServer();
    return {'url': url, 'isCustom': isCustom};
  }

  void showServerUrlDialog(BuildContext context, String currentUrl) {
    final controller = TextEditingController(text: currentUrl);
    final formKey = GlobalKey<FormState>();
    String? errorText;
    var isVerifying = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final l10nDialog = AppLocalizations.of(dialogContext);
          return AlertDialog(
            title: Text(l10nDialog.settingsServerUrl),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: l10nDialog.settingsServerUrlLabel,
                      hintText: defaultServerUrl,
                      errorText: errorText,
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                controller.clear();
                                setDialogState(() {});
                              },
                            )
                          : null,
                    ),
                    keyboardType: TextInputType.url,
                    autofillHints: const [AutofillHints.url],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10nDialog.commonCancel),
              ),
              if (currentUrl != defaultServerUrl)
                TextButton(
                  onPressed: () {
                    setServerUrl(null);
                    ApiClient().refreshServerUrl();
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(l10nDialog.settingsServerResetSuccess),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  },
                  child: Text(l10nDialog.settingsServerResetToDefault),
                ),
              FilledButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                        final url = controller.text.trim();

                        final validation = validateServerUrl(url);
                        if (!validation.valid) {
                          setDialogState(() {
                            errorText = validation.error;
                          });
                          return;
                        }

                        setDialogState(() {
                          errorText = null;
                          isVerifying = true;
                        });

                        final verificationResult = await verifyServerUrl(url);

                        setDialogState(() {
                          isVerifying = false;
                        });

                        if (!verificationResult.isValid) {
                          setDialogState(() {
                            errorText = l10nDialog.settingsServerNotReachable;
                          });
                          return;
                        }

                        setServerUrl(url);
                        unawaited(ApiClient().refreshServerUrl());

                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(l10nDialog.settingsServerSaved),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                child: isVerifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10nDialog.settingsServerSaveVerify),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsAbout,
      children: [
        _SettingsRow(
          icon: Icons.info_outline,
          title: l10n.commonVersion,
          subtitle: '1.0.0',
        ),
        _SettingsNavRow(
          icon: Icons.new_releases_outlined,
          title: "What's New",
          subtitle: 'Latest improvements and updates',
          onTap: () => context.pushNamed('changelog'),
        ),
        _SettingsNavRow(
          icon: Icons.code,
          title: 'GitHub',
          subtitle: 'slopus/happy',
          onTap: () => openUrl('https://github.com/slopus/happy'),
        ),
        _SettingsNavRow(
          icon: Icons.bug_report_outlined,
          title: 'Report an Issue',
          onTap: () => openUrl('https://github.com/slopus/happy/issues'),
        ),
        _SettingsNavRow(
          icon: Icons.privacy_tip_outlined,
          title: l10n.settingsPrivacyPolicy,
          onTap: () => openUrl('https://happy.dev/privacy'),
        ),
        _SettingsNavRow(
          icon: Icons.gavel_outlined,
          title: l10n.settingsTermsOfService,
          onTap: () => openUrl('https://happy.dev/terms'),
        ),
      ],
    );
  }

  String _avatarStyleLabel(String style) => switch (style) {
    'gradient' => 'Gradient',
    'pixelated' => 'Pixelated',
    'brutalist' => 'Brutalist',
    _ => style,
  };

  void showAvatarStyleDialog(
    BuildContext context,
    Settings settings,
    WidgetRef ref,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final l10nDialog = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10nDialog.settingsAvatarStyle),
          content: RadioGroup<String>(
            groupValue: settings.avatarStyle,
            onChanged: (value) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('avatarStyle', value);
              Navigator.pop(dialogContext);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ['gradient', 'pixelated', 'brutalist']
                  .map(
                    (style) => RadioListTile(
                      title: Text(_avatarStyleLabel(style)),
                      value: style,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      },
    );
  }

  void confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final l10nDialog = AppLocalizations.of(dialogContext);
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10nDialog.settingsSignOut),
          content: Text(l10nDialog.settingsSignOutConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10nDialog.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                ref.read(authStateNotifierProvider.notifier).signOut();
              },
              child: Text(l10nDialog.settingsSignOut),
            ),
          ],
        );
      },
    );
  }

  Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─── Private widget components ───────────────────────────────────────────────

/// Hero-area profile header with gradient backdrop, centered avatar,
/// name in headlineSmall, and bio/subtitle in bodyMedium.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final Profile? profile;

  static String _initialForName(String value) {
    if (value.isEmpty) return '?';
    return value.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final name = profile?.displayName?.trim();
    final avatarUrl = profile?.avatarUrl;
    final displayName = (name == null || name.isEmpty) ? 'Happy' : name;
    final bio = profile?.bio ?? 'Secure mobile companion for your sessions';

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface.withAlpha(150),
            border: Border.all(
              color: dark
                  ? Colors.white.withAlpha(20)
                  : Colors.black.withAlpha(10),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: cs.primaryContainer,
                backgroundImage: avatarUrl != null
                    ? ResizeImage(
                        NetworkImage(avatarUrl),
                        width: 216,
                        height: 216,
                      )
                    : null,
                child: avatarUrl == null
                    ? Text(
                        _initialForName(displayName),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                displayName,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                bio,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// A plain setting row: icon container + title/subtitle + optional trailing.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: SizedBox(
        height: subtitle != null ? null : 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _IconContainer(icon: icon, color: iconColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A setting row with a Switch.adaptive trailing widget.
class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            _IconContainer(icon: icon),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Switch.adaptive(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A setting row that navigates somewhere — includes a right chevron.
class _SettingsNavRow extends StatelessWidget {
  const _SettingsNavRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SettingsRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      trailing: Icon(
        Icons.chevron_right,
        size: 20,
        color: cs.onSurface.withValues(alpha: 0.3),
      ),
    );
  }
}

/// 36x36 rounded icon container used as the leading widget in rows.
class _IconContainer extends StatelessWidget {
  const _IconContainer({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = color ?? cs.primary;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, size: 18, color: effectiveColor),
    );
  }
}

/// Sign-out / account management area at the bottom of the settings list.
class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final errorColor = Theme.of(context).colorScheme.error;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.logout, size: 18),
        label: Text(l10n.settingsSignOut),
        style: OutlinedButton.styleFrom(
          foregroundColor: errorColor,
          side: BorderSide(color: errorColor),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        onPressed: () => _confirmSignOut(context, ref),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final l10nDialog = AppLocalizations.of(dialogContext);
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10nDialog.settingsSignOut),
          content: Text(l10nDialog.settingsSignOutConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10nDialog.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                ref.read(authStateNotifierProvider.notifier).signOut();
              },
              child: Text(l10nDialog.settingsSignOut),
            ),
          ],
        );
      },
    );
  }
}

// ─── Public SettingsSection (kept for external use) ─────────────────────────

/// Settings section wrapper (public API preserved for external callers).
class SettingsSection extends StatelessWidget {
  const SettingsSection({required this.children, super.key, this.title});

  /// Optional section heading text.
  final String? title;

  /// Child widgets rendered inside the section card.
  final List<Widget> children;

  // Leading padding (16) + icon container width (36) + icon gap (12) = 64.
  static const double _dividerIndent = AppSpacing.lg + 36 + AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              title!.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                fontSize: 12,
              ),
            ),
          ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: cs.outlineVariant),
          ),
          child: Column(children: _intersperse(children, cs)),
        ),
      ],
    );
  }

  /// Inserts a slim divider between children (but not before/after).
  List<Widget> _intersperse(List<Widget> items, ColorScheme cs) {
    if (items.length <= 1) return items;
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) {
        result.add(
          Divider(
            height: 1,
            thickness: 0.5,
            indent: _dividerIndent,
            endIndent: 0,
            color: cs.outlineVariant,
          ),
        );
      }
    }
    return result;
  }
}
