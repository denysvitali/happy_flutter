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
        padding: const EdgeInsets.all(16),
        children: [
          buildProfileHeader(context, profile),
          const SizedBox(height: 24),
          buildAppearanceSection(context, settings, ref),
          const SizedBox(height: 24),
          buildBehaviorSection(context, settings, ref),
          const SizedBox(height: 24),
          buildVoiceSection(context),
          const SizedBox(height: 24),
          buildConnectedAccountsSection(context, ref, profile),
          const SizedBox(height: 24),
          buildAIProfilesSection(context),
          const SizedBox(height: 24),
          buildUsageSection(context),
          const SizedBox(height: 24),
          buildFeaturesSection(context),
          const SizedBox(height: 24),
          buildSocialSection(context),
          const SizedBox(height: 24),
          buildMachinesSection(context, machines),
          const SizedBox(height: 24),
          buildAccountSection(context),
          const SizedBox(height: 24),
          buildCertificatesSection(context),
          const SizedBox(height: 24),
          buildServerSection(context),
          const SizedBox(height: 24),
          buildDeveloperSection(context, settings),
          const SizedBox(height: 24),
          buildAboutSection(context),
          const SizedBox(height: 24),
          buildSignOutSection(context, ref),
        ],
      ),
    );
  }

  Widget buildConnectedAccountsSection(
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
        ListTile(
          leading: const Icon(Icons.smart_toy_outlined),
          title: const Text('Claude Code'),
          subtitle: Text(claudeConnected ? 'Connected' : 'Not connected'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            if (claudeConnected) {
              try {
                await ServicesApi().disconnectClaude();
                await ref
                    .read(profileNotifierProvider.notifier)
                    .refreshFromSync();
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Claude disconnected')),
                );
              } catch (error) {
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to disconnect: $error')),
                );
              }
            } else {
              context.push('/settings/account');
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: const Text('GitHub'),
          subtitle: Text(
            github != null ? 'Connected as @${github.login}' : 'Not connected',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            if (github != null) {
              try {
                await GitHubApi().disconnectGitHub();
                await ref
                    .read(profileNotifierProvider.notifier)
                    .refreshFromSync();
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('GitHub disconnected')),
                );
              } catch (error) {
                if (!context.mounted) {
                  return;
                }
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
                if (!context.mounted) {
                  return;
                }
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

  Widget buildProfileHeader(BuildContext context, Profile? profile) {
    final theme = Theme.of(context);
    final name = profile?.displayName?.trim();
    final avatarUrl = profile?.avatarUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      _initialForName(name ?? 'H'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (name == null || name.isEmpty) ? 'Happy' : name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile?.bio ?? 'Secure mobile companion for your sessions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAppearanceSection(
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
        ListTile(
          title: Text(l10n.appearanceTheme),
          subtitle: Text(themeModeLabel),
          leading: const Icon(Icons.palette),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/theme'),
        ),
        ListTile(
          title: Text(l10n.settingsLanguage),
          subtitle: Text(
            settings.locale.isEmpty
                ? l10n.settingsLanguageAutomatic
                : _getLocaleDisplayName(settings.locale),
          ),
          leading: const Icon(Icons.language),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/language'),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: Text(l10n.settingsCompactSessionView),
          subtitle: Text(l10n.settingsCompactSessionViewSubtitle),
          value: settings.compactSessionView,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('compactSessionView', value),
        ),
        SwitchListTile(
          title: Text(l10n.settingsShowFlavorIcons),
          subtitle: Text(l10n.settingsShowFlavorIconsSubtitle),
          value: settings.showFlavorIcons,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('showFlavorIcons', value),
        ),
        ListTile(
          title: Text(l10n.settingsAvatarStyle),
          subtitle: Text(settings.avatarStyle),
          onTap: () => showAvatarStyleDialog(context, settings, ref),
        ),
      ],
    );
  }

  String _getLocaleDisplayName(String localeString) {
    if (localeString.isEmpty) return '';
    final parts = localeString.split('_');
    if (parts.length == 2) {
      return '${parts[0][0].toUpperCase()}${parts[0].substring(1)} (${parts[1]})';
    }
    return '${parts[0][0].toUpperCase()}${parts[0].substring(1)}';
  }

  Widget buildBehaviorSection(
    BuildContext context,
    Settings settings,
    WidgetRef ref,
  ) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsBehavior,
      children: [
        SwitchListTile(
          title: Text(l10n.settingsViewInline),
          subtitle: Text(l10n.settingsViewInlineSubtitle),
          value: settings.viewInline,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('viewInline', value),
        ),
        SwitchListTile(
          title: Text(l10n.settingsExpandTodos),
          value: settings.expandTodos,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('expandTodos', value),
        ),
        SwitchListTile(
          title: Text(l10n.settingsShowLineNumbers),
          value: settings.showLineNumbers,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('showLineNumbers', value),
        ),
        SwitchListTile(
          title: Text(l10n.settingsWrapLinesInDiffs),
          value: settings.wrapLinesInDiffs,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('wrapLinesInDiffs', value),
        ),
      ],
    );
  }

  Widget buildVoiceSection(BuildContext context) {
    return SettingsSection(
      title: 'Voice',
      children: [
        ListTile(
          title: const Text('Voice Settings'),
          subtitle: const Text('Configure ElevenLabs voice'),
          leading: const Icon(Icons.record_voice_over),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/voice'),
        ),
      ],
    );
  }

  Widget buildAIProfilesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsProfiles,
      children: [
        ListTile(
          title: Text(l10n.settingsProfiles),
          subtitle: Text(l10n.settingsProfilesSubtitle),
          leading: const Icon(Icons.account_tree),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/profiles'),
        ),
      ],
    );
  }

  Widget buildUsageSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsUsage,
      children: [
        ListTile(
          title: Text(l10n.settingsUsage),
          subtitle: Text(l10n.settingsUsageSubtitle),
          leading: const Icon(Icons.analytics),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/usage'),
        ),
      ],
    );
  }

  Widget buildFeaturesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsFeatures,
      children: [
        ListTile(
          title: Text(l10n.featuresExperiments),
          subtitle: Text(l10n.featuresExperimentsDesc),
          leading: const Icon(Icons.science),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/features'),
        ),
      ],
    );
  }

  Widget buildSocialSection(BuildContext context) {
    return SettingsSection(
      title: 'Social',
      children: [
        ListTile(
          title: const Text('Find Friends'),
          subtitle: const Text('Search and send friend requests'),
          leading: const Icon(Icons.person_add_alt_1),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/friends/search'),
        ),
        ListTile(
          title: const Text('Open Inbox'),
          subtitle: const Text('View updates and requests'),
          leading: const Icon(Icons.inbox_outlined),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/inbox'),
        ),
      ],
    );
  }

  Widget buildMachinesSection(
    BuildContext context,
    Map<String, Machine> machines,
  ) {
    if (machines.isEmpty) {
      return const SizedBox.shrink();
    }

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
                '${metadata?.platform ?? 'unknown'} • ${machine.active ? 'Online' : 'Offline'}';
            return ListTile(
              leading: Icon(
                Icons.computer_outlined,
                color: machine.active ? Colors.green : Colors.grey,
              ),
              title: Text(title),
              subtitle: Text(subtitle),
            );
          })
          .toList(growable: false),
    );
  }

  Widget buildDeveloperSection(BuildContext context, Settings settings) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsDeveloper,
      children: [
        ListTile(
          title: const Text('Developer Options'),
          subtitle: Text(
            settings.developerModeEnabled
                ? 'Enabled'
                : 'Tap 10 times to enable',
          ),
          leading: const Icon(Icons.build),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/developer'),
        ),
      ],
    );
  }

  Widget buildAccountSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsAccount,
      children: [
        ListTile(
          leading: const Icon(Icons.person),
          title: Text(l10n.accountAccountSettings),
          subtitle: const Text('Backup key, devices, services'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/account'),
        ),
      ],
    );
  }

  Widget buildCertificatesSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsCertificates,
      children: [
        FutureBuilder<bool>(
          future: Future.value(CertificateProvider().hasUserCertificates()),
          builder: (context, snapshot) {
            final hasCerts = snapshot.data ?? false;

            return ListTile(
              title: Text(l10n.settingsUserCaCertificates),
              subtitle: Text(
                hasCerts
                    ? l10n.settingsUserCertificatesInstalled
                    : l10n.settingsNoUserCertificates,
              ),
              trailing: hasCerts
                  ? Icon(Icons.check_circle, color: Colors.green[400])
                  : Icon(Icons.info_outline, color: Colors.grey[400]),
            );
          },
        ),
      ],
    );
  }

  Widget buildServerSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsServer,
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _getServerInfo(),
          builder: (context, snapshot) {
            final url = snapshot.data?['url'] as String? ?? 'Loading...';
            final isCustom = snapshot.data?['isCustom'] as bool? ?? false;

            return ListTile(
              title: Text(l10n.settingsServerUrl),
              subtitle: Text(url),
              trailing: isCustom
                  ? Icon(
                      Icons.edit,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : Icon(Icons.chevron_right),
              onTap: () => showServerUrlDialog(context, url),
            );
          },
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _getServerInfo() async {
    final url = await getServerUrl();
    final isCustom = await isUsingCustomServer();
    return {'url': url, 'isCustom': isCustom};
  }

  void showServerUrlDialog(BuildContext context, String currentUrl) {
    final controller = TextEditingController(text: currentUrl);
    final formKey = GlobalKey<FormState>();
    String? errorText;
    bool isVerifying = false;

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

                        // Validate URL format
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

                        // Verify server is reachable
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

                        // Save the URL
                        setServerUrl(url);
                        ApiClient().refreshServerUrl();

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

  Widget buildAboutSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.settingsAbout,
      children: [
        ListTile(
          title: Text(l10n.commonVersion),
          subtitle: const Text('1.0.0'),
        ),
        ListTile(
          title: const Text('What\'s New'),
          subtitle: const Text('Latest improvements and updates'),
          onTap: () => context.push('/settings/changelog'),
        ),
        ListTile(
          title: const Text('GitHub'),
          subtitle: const Text('slopus/happy'),
          onTap: () => openUrl('https://github.com/slopus/happy'),
        ),
        ListTile(
          title: const Text('Report an Issue'),
          onTap: () => openUrl('https://github.com/slopus/happy/issues'),
        ),
        ListTile(
          title: Text(l10n.settingsPrivacyPolicy),
          onTap: () => openUrl('https://happy.dev/privacy'),
        ),
        ListTile(
          title: Text(l10n.settingsTermsOfService),
          onTap: () => openUrl('https://happy.dev/terms'),
        ),
      ],
    );
  }

  Widget buildSignOutSection(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      children: [
        ListTile(
          title: Text(
            l10n.settingsSignOut,
            style: const TextStyle(color: Colors.red),
          ),
          leading: const Icon(Icons.logout, color: Colors.red),
          onTap: () => confirmSignOut(context, ref),
        ),
      ],
    );
  }

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
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: ['brutalist', 'minimal', 'rounded', 'circle']
                .map(
                  (style) => RadioListTile(
                    title: Text(style),
                    value: style,
                    groupValue: settings.avatarStyle,
                    onChanged: (value) {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .updateSetting('avatarStyle', value);
                      Navigator.pop(dialogContext);
                    },
                  ),
                )
                .toList(),
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
        return AlertDialog(
          title: Text(l10nDialog.settingsSignOut),
          content: Text(l10nDialog.settingsSignOutConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10nDialog.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  String _initialForName(String value) {
    if (value.isEmpty) {
      return '?';
    }
    return value.substring(0, 1).toUpperCase();
  }
}

/// Settings section wrapper
class SettingsSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const SettingsSection({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),
        Card(child: Column(children: children)),
      ],
    );
  }
}
