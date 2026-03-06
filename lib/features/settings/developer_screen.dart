import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_tokens.dart';

/// Developer screen - Debug tools (10x click to enable)
class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key});

  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsNotifierProvider);
    final isDeveloperMode = settings.developerModeEnabled;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.developerTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Developer mode toggle
          Card(
            child: SwitchListTile(
              title: Text(l10n.developerModeTitle),
              subtitle: Text(isDeveloperMode
                  ? l10n.developerModeEnabledDesc
                  : l10n.developerModeDisabledDesc),
              value: isDeveloperMode,
              onChanged: (value) {
                ref
                    .read(settingsNotifierProvider.notifier)
                    .updateSetting('developerModeEnabled', value);
              },
            ),
          ),
          if (isDeveloperMode) ...[
            const SizedBox(height: AppSpacing.xxl),
            _buildSectionHeader(l10n.developerSectionDebugTools),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: l10n.developerNetworkInspector,
              subtitle: l10n.developerNetworkInspectorDesc,
              icon: Icons.network_check,
              onTap: () =>
                  context.push('/settings/developer/network'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: l10n.settingsLogs,
              subtitle: l10n.developerLogsDesc,
              icon: Icons.terminal,
              onTap: () => context.push('/settings/developer/logs'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: l10n.developerEncryptionDebug,
              subtitle: l10n.developerEncryptionDebugDesc,
              icon: Icons.security,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.developerNotYetImplemented)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: l10n.developerSessionDebug,
              subtitle: l10n.developerSessionDebugDesc,
              icon: Icons.history,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.developerNotYetImplemented)),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildSectionHeader(l10n.developerSectionTesting),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: l10n.developerTestNotifications,
              subtitle: l10n.developerTestNotificationsDesc,
              icon: Icons.notifications,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.developerNotYetImplemented)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: l10n.developerTestSentryException,
              subtitle: l10n.developerTestSentryExceptionDesc,
              icon: Icons.bug_report,
              onTap: () async {
                try {
                  throw StateError('Sentry test exception');
                } catch (e, st) {
                  final eventId = await Sentry.captureException(
                    e,
                    stackTrace: st,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(context)
                              .developerSentToSentry('$eventId'),
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: l10n.developerTestSentryUnhandled,
              subtitle: l10n.developerTestSentryUnhandledDesc,
              icon: Icons.error,
              onTap: () {
                throw StateError(
                  'Sentry unhandled test error',
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildSectionHeader(l10n.developerSectionCacheStorage),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: l10n.developerClearCache,
              subtitle: l10n.developerClearCacheDesc,
              icon: Icons.delete_sweep,
              onTap: () => _clearCache(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: l10n.developerResetSettings,
              subtitle: l10n.developerResetSettingsDesc,
              icon: Icons.restart_alt,
              onTap: () => _resetSettings(context, ref),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildSectionHeader(l10n.developerSectionBuildInfo),
            const SizedBox(height: AppSpacing.sm),
            _buildInfoTile(l10n.developerAppVersion, '1.0.0'),
            _buildInfoTile(l10n.developerBuildNumber, '1'),
            _buildInfoTile(l10n.developerFlutterVersion, '3.38.7'),
            _buildInfoTile(l10n.developerDartVersion, '3.10+'),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.lg,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDebugOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  void _clearCache(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final l10nDialog = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10nDialog.developerClearCache),
          content: Text(l10nDialog.developerClearCacheConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10nDialog.commonCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await Storage().clearAll();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context).developerCacheCleared,
                      ),
                    ),
                  );
                }
              },
              child: Text(l10nDialog.developerClearCacheAction),
            ),
          ],
        );
      },
    );
  }

  void _resetSettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        final l10nDialog = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10nDialog.developerResetSettings),
          content: Text(l10nDialog.developerResetSettingsConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10nDialog.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await SettingsStorage().clearSettings();
                if (context.mounted) {
                  await ref
                      .read(settingsNotifierProvider.notifier)
                      .loadSettings();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context).developerSettingsReset,
                      ),
                    ),
                  );
                }
              },
              child: Text(l10nDialog.developerResetAction),
            ),
          ],
        );
      },
    );
  }
}
