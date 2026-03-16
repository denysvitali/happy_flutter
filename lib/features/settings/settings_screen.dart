import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/github_api.dart';
import '../../core/api/services_api.dart';
import '../../core/api/socket_io_client.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/profile.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/server_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

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
    final locale = ref.watch(settingsNotifierProvider.select((s) => s.locale));
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
          _ProfileHeader(profile: profile),
          const SizedBox(height: AppSpacing.xl),
          _buildAppearanceSection(
            context,
            themeMode: themeMode,
            locale: locale,
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
          _buildSocialSection(context),
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
          _DangerZone(onSignOut: () => confirmSignOut(context, ref)),
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
                  content: Text(
                    l10n.claudeConnectCliInfo,
                  ),
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
    required String locale,
    required bool showFlavorIcons,
    required String avatarStyle,
    required WidgetRef ref,
  }) {
    final l10n = AppLocalizations.of(context);

    return SettingsSection(
      title: l10n.settingsAppearance,
      children: [
        _InlineThemePicker(
          currentMode: themeMode,
          onChanged: (mode) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('themeMode', mode),
        ),
        SettingsNavRow(
          icon: Icons.language,
          title: l10n.settingsLanguage,
          subtitle: locale.isEmpty
              ? l10n.settingsLanguageAutomatic
              : _getLocaleDisplayName(locale),
          onTap: () => context.pushNamed('language'),
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
          title: l10n.featuresExperiments,
          subtitle: l10n.featuresExperimentsDesc,
          onTap: () => context.pushNamed('features'),
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

  Future<void> showServerUrlDialog(
    BuildContext context,
    String currentUrl,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final controller = TextEditingController(text: currentUrl);
        final formKey = GlobalKey<FormState>();
        String? errorText;
        var isVerifying = false;

        return StatefulBuilder(
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
                              tooltip: l10nDialog.commonClear,
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
                onPressed: () {
                  controller.dispose();
                  Navigator.pop(dialogContext);
                },
                child: Text(l10nDialog.commonCancel),
              ),
              if (currentUrl != defaultServerUrl)
                TextButton(
                  onPressed: () {
                    setServerUrl(null);
                    ApiClient().refreshServerUrl();
                    socketIoClient.refreshServerUrl(getServerUrl());
                    controller.dispose();
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
                        socketIoClient.refreshServerUrl(url);

                        if (dialogContext.mounted) {
                          controller.dispose();
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
                    ? Semantics(
                        label: 'Verifying...',
                        child: SizedBox(
                          width: AppSpacing.lg,
                          height: AppSpacing.lg,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      )
                    : Text(l10nDialog.settingsServerSaveVerify),
              ),
            ],
          );
        },
      );
    });
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
              children: [
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
    final state = context.findAncestorStateOfType<_SettingsScreenState>();
    if (state == null) return;
    await state.showServerUrlDialog(context, currentUrl);
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
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: AppOpacity.medium),
              ),
              onTap: () => _showServerUrlDialog(context, url),
            );
          },
        ),
      ],
    );
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
      clipBehavior: Clip.hardEdge,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cs.primaryContainer.withValues(
                  alpha: dark ? 0.31 : 0.24,
                ),
                cs.surface.withValues(alpha: 0.59),
              ],
            ),
            border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: AppOpacity.faint)
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: cs.primaryContainer,
                backgroundImage: avatarUrl != null
                    ? CachedNetworkImageProvider(
                        avatarUrl,
                        maxWidth: 216,
                        maxHeight: 216,
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
              const SizedBox(height: AppSpacing.md),
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

/// Danger zone section with sign-out in a red-tinted card.
class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.onSignOut});

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

/// Inline theme picker showing three selectable chips for theme modes.
class _InlineThemePicker extends StatelessWidget {
  const _InlineThemePicker({
    required this.currentMode,
    required this.onChanged,
  });

  final String currentMode;
  final ValueChanged<String> onChanged;

  static const _modes = [
    ('adaptive', Icons.brightness_auto, 'Auto'),
    ('light', Icons.light_mode, 'Light'),
    ('dark', Icons.dark_mode, 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SettingsIconContainer(icon: Icons.palette),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Row(
              children: _modes.map((m) {
                final selected = m.$1 == currentMode;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxxs,
                    ),
                    child: AnimatedContainer(
                      duration: AppDuration.fast,
                      curve: AppCurve.standard,
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AppRadius.sm,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppRadius.sm,
                        ),
                        child: InkWell(
                          onTap: () => onChanged(m.$1),
                          borderRadius: BorderRadius.circular(
                            AppRadius.sm,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  m.$2,
                                  size: 20,
                                  color: selected
                                      ? cs.onPrimaryContainer
                                      : cs.onSurfaceVariant,
                                ),
                                const SizedBox(
                                  height: AppSpacing.xs,
                                ),
                                Text(
                                  m.$3,
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(
                                    color: selected
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
