import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/certificate_provider.dart';
import '../../core/services/server_config.dart';
import 'language_selector.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          buildAppearanceSection(context, settings, ref),
          const SizedBox(height: 24),
          buildBehaviorSection(context, settings, ref),
          const SizedBox(height: 24),
          buildVoiceSection(context),
          const SizedBox(height: 24),
          buildAIProfilesSection(context),
          const SizedBox(height: 24),
          buildUsageSection(context),
          const SizedBox(height: 24),
          buildFeaturesSection(context),
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

  Widget buildAppearanceSection(
    BuildContext context,
    Settings settings,
    WidgetRef ref,
  ) {
    final themeModeLabel = switch (settings.themeMode) {
      'light' => AppLocalizations.of(context).appearanceThemeLight,
      'dark' => AppLocalizations.of(context).appearanceThemeDark,
      'adaptive' => AppLocalizations.of(context).appearanceThemeAdaptive,
      _ => AppLocalizations.of(context).appearanceThemeAdaptive,
    };

    return SettingsSection(
      title: AppLocalizations.of(context).settingsAppearance,
      children: [
        ListTile(
          title: Text(AppLocalizations.of(context).appearanceTheme),
          subtitle: Text(themeModeLabel),
          leading: const Icon(Icons.palette),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/theme'),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context).settingsLanguage),
          subtitle: Text(settings.locale.isEmpty
              ? AppLocalizations.of(context).settingsLanguageAutomatic
              : _getLocaleDisplayName(settings.locale)),
          leading: const Icon(Icons.language),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/language'),
        ),
        const Divider(height: 1),
        SwitchListTile(
          title: Text(AppLocalizations.of(context).settingsCompactSessionView),
          subtitle: Text(AppLocalizations.of(context).settingsCompactSessionViewSubtitle),
          value: settings.compactSessionView,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('compactSessionView', value),
        ),
        SwitchListTile(
          title: Text(AppLocalizations.of(context).settingsShowFlavorIcons),
          subtitle: Text(AppLocalizations.of(context).settingsShowFlavorIconsSubtitle),
          value: settings.showFlavorIcons,
          onChanged: (value) => ref
              .read(settingsNotifierProvider.notifier)
              .updateSetting('showFlavorIcons', value),
        ),
        ListTile(
          title: Text(AppLocalizations.of(context).settingsAvatarStyle),
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
    final l10n = AppLocalizations.of(context);
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context).settingsServerUrl),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).settingsServerUrlLabel,
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
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).commonCancel),
            ),
            if (currentUrl != defaultServerUrl)
              TextButton(
                onPressed: () {
                  setServerUrl(null);
                  ApiClient().refreshServerUrl();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppLocalizations.of(context).settingsServerResetSuccess),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                child: Text(AppLocalizations.of(context).settingsServerResetToDefault),
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
                          errorText = AppLocalizations.of(context).settingsServerNotReachable;
                        });
                        return;
                      }

                      // Save the URL
                      setServerUrl(url);
                      ApiClient().refreshServerUrl();

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLocalizations.of(context).settingsServerSaved),
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
                  : Text(AppLocalizations.of(context).settingsServerSaveVerify),
            ),
          ],
        ),
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
          subtitle: Text(l10n.settingsVersion),
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
          title: Text(l10n.settingsSignOut, style: const TextStyle(color: Colors.red)),
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
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsAvatarStyle),
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
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void confirmSignOut(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.settingsSignOut),
        content: Text(l10n.settingsSignOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ref.read(authStateNotifierProvider.notifier).signOut();
            },
            child: Text(l10n.settingsSignOut),
          ),
        ],
      ),
    );
  }

  void openUrl(String url) {
    // Implement URL opening
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
