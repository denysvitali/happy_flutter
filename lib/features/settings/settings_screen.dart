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
import '../../core/models/machine.dart';
import '../../core/models/profile.dart';
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
    final showLineNumbers = ref.watch(
      settingsNotifierProvider.select((s) => s.showLineNumbers),
    );
    final wrapLinesInDiffs = ref.watch(
      settingsNotifierProvider.select((s) => s.wrapLinesInDiffs),
    );
    final ttsEnabled = ref.watch(
      settingsNotifierProvider.select((s) => s.ttsEnabled),
    );
    final developerModeEnabled = ref.watch(
      settingsNotifierProvider.select((s) => s.developerModeEnabled),
    );
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
            showLineNumbers: showLineNumbers,
            wrapLinesInDiffs: wrapLinesInDiffs,
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
          _buildMachinesSection(context, machines),
          if (machines.isNotEmpty) const SizedBox(height: AppSpacing.lg),
          _buildAccountSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildCertificatesSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildServerSection(context),
          const SizedBox(height: AppSpacing.lg),
          _buildDeveloperSection(
            context,
            developerModeEnabled: developerModeEnabled,
          ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(claudeMsg)),
                );
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(failMsg(error.toString()))),
                );
              }
            } else {
              unawaited(context.pushNamed('account'));
            }
          },
        ),
        SettingsNavRow(
          icon: Icons.code,
          title: 'GitHub',
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(githubMsg)),
                );
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
    final themeModeLabel = switch (themeMode) {
      'light' => l10n.appearanceThemeLight,
      'dark' => l10n.appearanceThemeDark,
      'adaptive' => l10n.appearanceThemeAdaptive,
      _ => l10n.appearanceThemeAdaptive,
    };

    return SettingsSection(
      title: l10n.settingsAppearance,
      children: [
        SettingsNavRow(
          icon: Icons.palette,
          title: l10n.appearanceTheme,
          subtitle: themeModeLabel,
          onTap: () => context.pushNamed('theme'),
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
    required bool showLineNumbers,
    required bool wrapLinesInDiffs,
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
        SettingsToggleRow(
          icon: Icons.format_list_numbered,
          title: l10n.settingsShowLineNumbers,
          value: showLineNumbers,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('showLineNumbers', value),
        ),
        SettingsToggleRow(
          icon: Icons.wrap_text,
          title: l10n.settingsWrapLinesInDiffs,
          value: wrapLinesInDiffs,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('wrapLinesInDiffs', value),
        ),
      ],
    );
  }

  Widget _buildVoiceSection(
    BuildContext context, {
    required bool ttsEnabled,
    required WidgetRef ref,
  }) {
    return SettingsSection(
      title: 'Voice',
      children: [
        SettingsToggleRow(
          icon: Icons.volume_up_outlined,
          title: 'Text-to-Speech',
          subtitle: 'Read assistant messages aloud',
          value: ttsEnabled,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('ttsEnabled', value),
        ),
        SettingsNavRow(
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
    return SettingsSection(
      title: 'Social',
      children: [
        SettingsNavRow(
          icon: Icons.person_add_alt_1,
          title: 'Find Friends',
          subtitle: 'Search and send friend requests',
          onTap: () => context.pushNamed('friends-search'),
        ),
        SettingsNavRow(
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
            return SettingsRow(
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
          title: 'Developer Options',
          subtitle: developerModeEnabled ? 'Enabled' : 'Tap 10 times to enable',
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
            return SettingsRow(
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

            return SettingsRow(
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
                    socketIoClient.refreshServerUrl(getServerUrl());
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
        SettingsRow(
          icon: Icons.info_outline,
          title: l10n.commonVersion,
          subtitle: '1.0.0',
        ),
        SettingsNavRow(
          icon: Icons.new_releases_outlined,
          title: "What's New",
          subtitle: 'Latest improvements and updates',
          onTap: () => context.pushNamed('changelog'),
        ),
        SettingsNavRow(
          icon: Icons.code,
          title: 'GitHub',
          subtitle: 'slopus/happy',
          onTap: () => openUrl('https://github.com/slopus/happy'),
        ),
        SettingsNavRow(
          icon: Icons.bug_report_outlined,
          title: 'Report an Issue',
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
      clipBehavior: Clip.hardEdge,
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
