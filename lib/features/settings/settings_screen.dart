import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/github_api.dart';
import '../../core/api/services_api.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/profile.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/server_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'helpers/server_url_dialog.dart';
import 'widgets/danger_zone.dart';
import 'widgets/inline_theme_picker.dart';
import 'widgets/profile_header.dart';

// ─── Settings Screen ─────────────────────────────────────────────────────────

/// Settings screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(
      settingsNotifierProvider.select((s) => s.themeMode),
    );
    final showFlavorIcons = ref.watch(
      settingsNotifierProvider.select((s) => s.showFlavorIcons),
    );
    final avatarStyle = ref.watch(
      settingsNotifierProvider.select((s) => s.avatarStyle),
    );
    final viewInline = ref.watch(
      settingsNotifierProvider.select((s) => s.viewInline),
    );
    final expandTodos = ref.watch(
      settingsNotifierProvider.select((s) => s.expandTodos),
    );
    final ttsEnabled = ref.watch(
      settingsNotifierProvider.select((s) => s.ttsEnabled),
    );
    final developerModeEnabled = ref.watch(
      settingsNotifierProvider.select((s) => s.developerModeEnabled),
    );
    final profile = ref.watch(profileNotifierProvider);
    // Select only the machine count and first machine's display name/host to
    // avoid rebuilding this screen when unrelated machine fields change.
    final machineCount = ref.watch(
      machinesNotifierProvider.select((m) => m.length),
    );
    final firstMachineSubtitle = ref.watch(
      machinesNotifierProvider.select((m) {
        if (m.isEmpty) return null;
        final first = m.values.first;
        return first.metadata?.displayName ?? first.metadata?.host;
      }),
    );
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          ProfileHeader(profile: profile),
          const SizedBox(height: AppSpacing.xl),
          _buildAppearanceSection(
            context,
            themeMode: themeMode,
            showFlavorIcons: showFlavorIcons,
            avatarStyle: avatarStyle,
            ref: ref,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildBehaviorSection(
            context,
            viewInline: viewInline,
            expandTodos: expandTodos,
            ref: ref,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildVoiceSection(context, ttsEnabled: ttsEnabled, ref: ref),
          const SizedBox(height: AppSpacing.lg),
          _buildConnectedAccountsSection(context, ref, profile),
          const SizedBox(height: AppSpacing.lg),
          _buildAIProfilesSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildUsageSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildFeaturesSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildSmartFeaturesSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildSocialSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildSessionsSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildMachinesSection(
            context,
            machineCount: machineCount,
            firstMachineSubtitle: firstMachineSubtitle,
          ),
          if (machineCount > 0) const SizedBox(height: AppSpacing.lg),
          _buildAccountSection(context),
          const SizedBox(height: AppSpacing.lg),
          const _ServerSection(),
          const SizedBox(height: AppSpacing.lg),
          _buildDeveloperSection(
            context,
            developerModeEnabled: developerModeEnabled,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildAboutSection(context),
          const SizedBox(height: AppSpacing.xl),
          DangerZone(onSignOut: () => confirmSignOut(context, ref)),
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

    final l10n = context.l10n;
    return SettingsSection(
      title: l10n.settingsConnectedAccounts,
      children: [
        SettingsNavRow(
          icon: Icons.smart_toy_outlined,
          title: l10n.settingsClaudeCode,
          subtitle: claudeConnected
              ? l10n.settingsConnected
              : l10n.settingsNotConnected,
          onTap: () async {
            final claudeMsg = l10n.settingsClaudeDisconnected;
            final failMsg = l10n.settingsFailedToDisconnect;
            if (claudeConnected) {
              try {
                await ServicesApi().disconnectClaude();
                await ref
                    .read(profileNotifierProvider.notifier)
                    .refreshFromSync();
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(claudeMsg)));
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(failMsg(error.toString()))),
                );
              }
            } else {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.claudeConnectCliInfo),
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
        ),
        SettingsNavRow(
          icon: Icons.code,
          title: l10n.settingsGitHub,
          subtitle: github != null
              ? l10n.settingsConnectedAs(github.login)
              : l10n.settingsNotConnected,
          onTap: () async {
            final githubMsg = l10n.settingsGitHubDisconnected;
            final failMsg = l10n.settingsFailedToDisconnect;
            final oauthFailMsg = l10n.settingsFailedToStartOAuth;
            if (github != null) {
              try {
                await GitHubApi().disconnectGitHub();
                await ref
                    .read(profileNotifierProvider.notifier)
                    .refreshFromSync();
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(githubMsg)));
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(failMsg(error.toString()))),
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
                  SnackBar(content: Text(oauthFailMsg(error.toString()))),
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(
    BuildContext context, {
    required String themeMode,
    required bool showFlavorIcons,
    required String avatarStyle,
    required WidgetRef ref,
  }) {
    final l10n = AppLocalizations.of(context);

    return SettingsSection(
      title: l10n.settingsAppearance,
      children: [
        InlineThemePicker(
          currentMode: themeMode,
          onChanged: (mode) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('themeMode', mode),
        ),
        SettingsToggleRow(
          icon: Icons.emoji_emotions_outlined,
          title: l10n.settingsShowFlavorIcons,
          subtitle: l10n.settingsShowFlavorIconsSubtitle,
          value: showFlavorIcons,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('showFlavorIcons', value),
        ),
        SettingsNavRow(
          icon: Icons.account_circle_outlined,
          title: l10n.settingsAvatarStyle,
          subtitle: avatarStyle,
          onTap: () => showAvatarStyleDialog(context, avatarStyle, ref),
        ),
      ],
    );
  }

  Widget _buildBehaviorSection(
    BuildContext context, {
    required bool viewInline,
    required bool expandTodos,
    required WidgetRef ref,
  }) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsBehavior,
      children: [
        SettingsToggleRow(
          icon: Icons.open_in_new_outlined,
          title: l10n.settingsViewInline,
          subtitle: l10n.settingsViewInlineSubtitle,
          value: viewInline,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('viewInline', value),
        ),
        SettingsToggleRow(
          icon: Icons.check_box_outlined,
          title: l10n.settingsExpandTodos,
          value: expandTodos,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('expandTodos', value),
        ),
      ],
    );
  }

  Widget _buildVoiceSection(
    BuildContext context, {
    required bool ttsEnabled,
    required WidgetRef ref,
  }) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsVoice,
      children: [
        SettingsToggleRow(
          icon: Icons.volume_up_outlined,
          title: l10n.settingsTextToSpeech,
          subtitle: l10n.settingsTextToSpeechSubtitle,
          value: ttsEnabled,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('ttsEnabled', value),
        ),
        SettingsNavRow(
          icon: Icons.record_voice_over,
          title: l10n.settingsVoiceSettings,
          subtitle: l10n.settingsConfigureVoiceAssistant,
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
        SettingsNavRow(
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
        SettingsNavRow(
          icon: Icons.analytics,
          title: l10n.settingsUsage,
          subtitle: l10n.settingsUsageSubtitle,
          onTap: () => context.pushNamed('usage'),
        ),
        SettingsNavRow(
          icon: Icons.speed,
          title: l10n.claudeCodeLimits,
          subtitle: l10n.claudeCodeLimitsSubtitle,
          onTap: () => context.pushNamed('claude-limits'),
        ),
        SettingsNavRow(
          icon: Icons.code,
          title: l10n.codexUsageTitle,
          subtitle: l10n.codexUsageSubtitle,
          onTap: () => context.pushNamed('codex-usage'),
        ),
      ],
    );
  }

  Widget _buildFeaturesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsFeatures,
      children: [
        SettingsNavRow(
          icon: Icons.science,
          title: l10n.settingsFeatures,
          subtitle: l10n.settingsFeaturesSubtitle,
          onTap: () => context.pushNamed('features'),
        ),
      ],
    );
  }

  Widget _buildSmartFeaturesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.smartFeaturesTitle,
      children: [
        SettingsNavRow(
          icon: Icons.auto_awesome,
          title: l10n.smartFeaturesTitle,
          subtitle: l10n.smartFeaturesEnabledDesc,
          onTap: () => context.pushNamed('smart-features'),
        ),
      ],
    );
  }

  Widget _buildSocialSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsSocial,
      children: [
        SettingsNavRow(
          icon: Icons.person_add_alt_1,
          title: l10n.settingsFindFriends,
          subtitle: l10n.settingsFindFriendsSubtitle,
          onTap: () => context.pushNamed('friends-search'),
        ),
        SettingsNavRow(
          icon: Icons.inbox_outlined,
          title: l10n.settingsOpenInbox,
          subtitle: l10n.settingsOpenInboxSubtitle,
          onTap: () => context.pushNamed('inbox'),
        ),
      ],
    );
  }

  Widget _buildSessionsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsSessions,
      children: [
        SettingsNavRow(
          icon: Icons.folder_outlined,
          title: l10n.sessionsFolders,
          subtitle: l10n.sessionsFolders,
          onTap: () => context.pushNamed('sessions-folders'),
        ),
        SettingsNavRow(
          icon: Icons.auto_awesome_outlined,
          title: l10n.autoArchiveTitle,
          subtitle: l10n.autoArchiveSection,
          onTap: () => context.pushNamed('sessions-auto-archive'),
        ),
      ],
    );
  }

  Widget _buildMachinesSection(
    BuildContext context, {
    required int machineCount,
    required String? firstMachineSubtitle,
  }) {
    if (machineCount == 0) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsMachines,
      children: [
        SettingsNavRow(
          icon: Icons.computer_outlined,
          title: l10n.settingsMachines,
          subtitle: firstMachineSubtitle,
          onTap: () => context.pushNamed('machines'),
        ),
      ],
    );
  }

  Widget _buildDeveloperSection(
    BuildContext context, {
    required bool developerModeEnabled,
  }) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsDeveloper,
      children: [
        SettingsNavRow(
          icon: Icons.build,
          title: l10n.settingsDeveloperOptions,
          subtitle: developerModeEnabled
              ? l10n.settingsDeveloperEnabled
              : l10n.settingsDeveloperTapToEnable,
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
        SettingsNavRow(
          icon: Icons.person,
          title: l10n.accountAccountSettings,
          subtitle: l10n.settingsAccountSubtitle,
          onTap: () => context.pushNamed('account'),
        ),
        SettingsNavRow(
          icon: Icons.devices_outlined,
          title: l10n.accountLinkedDevices,
          subtitle: l10n.accountLinkedDevicesSubtitle,
          onTap: () => context.pushNamed('devices'),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsAbout,
      children: [
        SettingsNavRow(
          icon: Icons.code,
          title: l10n.settingsGitHub,
          subtitle: 'slopus/happy',
          onTap: () => openUrl('https://github.com/slopus/happy'),
        ),
        SettingsNavRow(
          icon: Icons.bug_report_outlined,
          title: l10n.settingsReportIssue,
          onTap: () => openUrl('https://github.com/slopus/happy/issues'),
        ),
        SettingsNavRow(
          icon: Icons.privacy_tip_outlined,
          title: l10n.settingsPrivacyPolicy,
          onTap: () => openUrl('https://happy.dev/privacy'),
        ),
        SettingsNavRow(
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
    'geometric' => 'Geometric',
    'rings' => 'Rings',
    'constellation' => 'Constellation',
    'wave' => 'Wave',
    _ => style,
  };

  void showAvatarStyleDialog(
    BuildContext context,
    String currentAvatarStyle,
    WidgetRef ref,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final l10nDialog = AppLocalizations.of(dialogContext);
        return AlertDialog(
          title: Text(l10nDialog.settingsAvatarStyle),
          content: RadioGroup<String>(
            groupValue: currentAvatarStyle,
            onChanged: (value) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('avatarStyle', value);
              Navigator.pop(dialogContext);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  [
                        'gradient',
                        'pixelated',
                        'brutalist',
                        'geometric',
                        'rings',
                        'constellation',
                        'wave',
                      ]
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
                foregroundColor: colorScheme.onError,
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

class _ServerSection extends StatefulWidget {
  const _ServerSection();

  @override
  State<_ServerSection> createState() => _ServerSectionState();
}

class _ServerSectionState extends State<_ServerSection> {
  late Future<Map<String, dynamic>> _serverInfoFuture;

  @override
  void initState() {
    super.initState();
    _serverInfoFuture = _getServerInfo();
  }

  Future<Map<String, dynamic>> _getServerInfo() async {
    final url = getServerUrl();
    final isCustom = isUsingCustomServer();
    return {'url': url, 'isCustom': isCustom};
  }

  Future<void> _showServerUrlDialog(
    BuildContext context,
    String currentUrl,
  ) async {
    await showServerUrlDialog(context, currentUrl);
    if (!mounted) return;
    setState(() {
      _serverInfoFuture = _getServerInfo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsServer,
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _serverInfoFuture,
          builder: (context, snapshot) {
            final url = snapshot.data?['url'] as String? ?? 'Loading...';
            final isCustom = snapshot.data?['isCustom'] as bool? ?? false;

            return SettingsRow(
              icon: isCustom ? Icons.edit : Icons.cloud_outlined,
              title: l10n.settingsServerUrl,
              subtitle: url,
              trailing: Icon(
                isCustom ? Icons.edit : Icons.chevron_right,
                size: 20,
                color: isCustom
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: AppOpacity.medium,
                      ),
              ),
              onTap: () => _showServerUrlDialog(context, url),
            );
          },
        ),
      ],
    );
  }
}
