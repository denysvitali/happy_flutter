import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          buildAppearanceSection(context, settings, ref),
          const SizedBox(height: 24),
          buildBehaviorSection(context, settings, ref),
          const SizedBox(height: 24),
          buildCertificatesSection(context),
          const SizedBox(height: 24),
          buildServerSection(context),
          const SizedBox(height: 24),
          buildAboutSection(context),
          const SizedBox(height: 24),
          buildSignOutSection(ref),
        ],
      ),
    );
  }

  Widget buildAppearanceSection(
    BuildContext context,
    Settings settings,
    WidgetRef ref,
  ) {
    return SettingsSection(
      title: 'Appearance',
      children: [
        SwitchListTile(
          title: const Text('Compact Session View'),
          subtitle: const Text('Use smaller cards for sessions'),
          value: settings.compactSessionView,
          onChanged: (value) =>
              ref.read(settingsNotifierProvider.notifier).updateSetting(
                    'compactSessionView',
                    value,
                  ),
        ),
        SwitchListTile(
          title: const Text('Show Flavor Icons'),
          subtitle: const Text('Show AI provider icons in avatars'),
          value: settings.showFlavorIcons,
          onChanged: (value) =>
              ref.read(settingsNotifierProvider.notifier).updateSetting(
                    'showFlavorIcons',
                    value,
                  ),
        ),
        ListTile(
          title: const Text('Avatar Style'),
          subtitle: Text(settings.avatarStyle),
          onTap: () => showAvatarStyleDialog(context, settings, ref),
        ),
      ],
    );
  }

  Widget buildBehaviorSection(
    BuildContext context,
    Settings settings,
    WidgetRef ref,
  ) {
    return SettingsSection(
      title: 'Behavior',
      children: [
        SwitchListTile(
          title: const Text('View Inline'),
          subtitle: const Text('Show tool calls inline in chat'),
          value: settings.viewInline,
          onChanged: (value) =>
              ref.read(settingsNotifierProvider.notifier).updateSetting(
                    'viewInline',
                    value,
                  ),
        ),
        SwitchListTile(
          title: const Text('Expand Todos'),
          value: settings.expandTodos,
          onChanged: (value) =>
              ref.read(settingsNotifierProvider.notifier).updateSetting(
                    'expandTodos',
                    value,
                  ),
        ),
        SwitchListTile(
          title: const Text('Show Line Numbers'),
          value: settings.showLineNumbers,
          onChanged: (value) =>
              ref.read(settingsNotifierProvider.notifier).updateSetting(
                    'showLineNumbers',
                    value,
                  ),
        ),
        SwitchListTile(
          title: const Text('Wrap Lines in Diffs'),
          value: settings.wrapLinesInDiffs,
          onChanged: (value) =>
              ref.read(settingsNotifierProvider.notifier).updateSetting(
                    'wrapLinesInDiffs',
                    value,
                  ),
        ),
      ],
    );
  }

  Widget buildCertificatesSection(BuildContext context) {
    return SettingsSection(
      title: 'Certificates',
      children: [
        FutureBuilder<bool>(
          future: Future.value(CertificateProvider().hasUserCertificates()),
          builder: (context, snapshot) {
            final hasCerts = snapshot.data ?? false;

            return ListTile(
              title: const Text('User CA Certificates'),
              subtitle: Text(
                hasCerts
                    ? 'User certificates are installed'
                    : 'No user certificates installed',
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
    return SettingsSection(
      title: 'Server',
      children: [
        FutureBuilder<Map<String, dynamic>>(
          future: _getServerInfo(),
          builder: (context, snapshot) {
            final url = snapshot.data?['url'] as String? ?? 'Loading...';
            final isCustom = snapshot.data?['isCustom'] as bool? ?? false;

            return ListTile(
              title: const Text('Server URL'),
              subtitle: Text(url),
              trailing: isCustom
                  ? Icon(Icons.edit, color: Theme.of(context).colorScheme.primary)
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
          title: const Text('Server URL'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Server URL',
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
                const SizedBox(height: 8),
                Text(
                  'Changes will take effect after restarting the app.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (currentUrl != defaultServerUrl)
              TextButton(
                onPressed: () async {
                  await setServerUrl(null);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Server URL reset to default. Restart app to apply.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                },
                child: const Text('Reset to Default'),
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
                      final isValid = await verifyServerUrl(url);

                      setDialogState(() {
                        isVerifying = false;
                      });

                      if (!isValid) {
                        setDialogState(() {
                          errorText = 'Server is not reachable. Check the URL and try again.';
                        });
                        return;
                      }

                      // Save the URL
                      await setServerUrl(url);

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Server URL saved. Restart app to apply changes.'),
                            duration: Duration(seconds: 3),
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
                  : const Text('Save & Verify'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAboutSection(BuildContext context) {
    return SettingsSection(
      title: 'About',
      children: [
        const ListTile(
          title: Text('Version'),
          subtitle: Text('1.0.0'),
        ),
        ListTile(
          title: const Text('Privacy Policy'),
          onTap: () => openUrl('https://happy.dev/privacy'),
        ),
        ListTile(
          title: const Text('Terms of Service'),
          onTap: () => openUrl('https://happy.dev/terms'),
        ),
      ],
    );
  }

  Widget buildSignOutSection(WidgetRef ref) {
    return SettingsSection(
      children: [
        ListTile(
          title: const Text(
            'Sign Out',
            style: TextStyle(color: Colors.red),
          ),
          leading: const Icon(Icons.logout, color: Colors.red),
          onTap: () => confirmSignOut(ref),
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
      builder: (context) => AlertDialog(
        title: const Text('Avatar Style'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['brutalist', 'minimal', 'rounded', 'circle']
              .map(
                (style) => RadioListTile(
                  title: Text(style),
                  value: style,
                  groupValue: settings.avatarStyle,
                  onChanged: (value) {
                    ref.read(settingsNotifierProvider.notifier).updateSetting(
                          'avatarStyle',
                          value,
                        );
                    Navigator.pop(context);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void confirmSignOut(WidgetRef ref) {
    showDialog(
      context: ref.context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              ref.read(authStateNotifierProvider.notifier).signOut();
            },
            child: const Text('Sign Out'),
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
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }
}
