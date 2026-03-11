import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../core/components/settings_section.dart';
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        children: [
          SettingsSection(
            title: l10n.developerModeTitle,
            children: [
              SettingsToggleRow(
                icon: Icons.developer_mode,
                title: l10n.developerModeTitle,
                subtitle: isDeveloperMode
                    ? l10n.developerModeEnabledDesc
                    : l10n.developerModeDisabledDesc,
                value: isDeveloperMode,
                onChanged: (value) {
                  ref
                      .read(
                        settingsNotifierProvider.notifier,
                      )
                      .updateSetting(
                        'developerModeEnabled',
                        value,
                      );
                },
              ),
            ],
          ),
          if (isDeveloperMode) ...[
            const SizedBox(height: AppSpacing.lg),
            SettingsSection(
              title: l10n.developerSectionDebugTools,
              children: [
                SettingsNavRow(
                  icon: Icons.network_check,
                  title: l10n.developerNetworkInspector,
                  subtitle:
                      l10n.developerNetworkInspectorDesc,
                  onTap: () => context.push(
                    '/settings/developer/network',
                  ),
                ),
                SettingsNavRow(
                  icon: Icons.terminal,
                  title: l10n.settingsLogs,
                  subtitle: l10n.developerLogsDesc,
                  onTap: () => context.push(
                    '/settings/developer/logs',
                  ),
                ),
                SettingsNavRow(
                  icon: Icons.security,
                  title: l10n.developerEncryptionDebug,
                  subtitle:
                      l10n.developerEncryptionDebugDesc,
                  onTap: () =>
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.developerNotYetImplemented,
                      ),
                    ),
                  ),
                ),
                SettingsNavRow(
                  icon: Icons.history,
                  title: l10n.developerSessionDebug,
                  subtitle:
                      l10n.developerSessionDebugDesc,
                  onTap: () =>
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.developerNotYetImplemented,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsSection(
              title: l10n.developerSectionTesting,
              children: [
                SettingsNavRow(
                  icon: Icons.notifications,
                  title: l10n.developerTestNotifications,
                  subtitle:
                      l10n.developerTestNotificationsDesc,
                  onTap: () =>
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.developerNotYetImplemented,
                      ),
                    ),
                  ),
                ),
                SettingsNavRow(
                  icon: Icons.bug_report,
                  title:
                      l10n.developerTestSentryException,
                  subtitle:
                      l10n.developerTestSentryExceptionDesc,
                  onTap: () async {
                    try {
                      throw StateError(
                        'Sentry test exception',
                      );
                    } catch (e, st) {
                      final eventId =
                          await Sentry.captureException(
                        e,
                        stackTrace: st,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(context)
                                  .developerSentToSentry(
                                '$eventId',
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
                SettingsNavRow(
                  icon: Icons.error,
                  title:
                      l10n.developerTestSentryUnhandled,
                  subtitle:
                      l10n.developerTestSentryUnhandledDesc,
                  onTap: () {
                    throw StateError(
                      'Sentry unhandled test error',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsSection(
              title: l10n.developerSectionCacheStorage,
              children: [
                SettingsNavRow(
                  icon: Icons.delete_sweep,
                  title: l10n.developerClearCache,
                  subtitle: l10n.developerClearCacheDesc,
                  onTap: () => _clearCache(context),
                ),
                SettingsNavRow(
                  icon: Icons.restart_alt,
                  title: l10n.developerResetSettings,
                  subtitle:
                      l10n.developerResetSettingsDesc,
                  onTap: () =>
                      _resetSettings(context, ref),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsSection(
              title: l10n.developerSectionBuildInfo,
              children: [
                SettingsRow(
                  icon: Icons.info_outline,
                  title: l10n.developerAppVersion,
                  subtitle: '1.0.0',
                ),
                SettingsRow(
                  icon: Icons.numbers,
                  title: l10n.developerBuildNumber,
                  subtitle: '1',
                ),
                SettingsRow(
                  icon: Icons.flutter_dash,
                  title: l10n.developerFlutterVersion,
                  subtitle: '3.38.7',
                ),
                SettingsRow(
                  icon: Icons.code,
                  title: l10n.developerDartVersion,
                  subtitle: '3.10+',
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.xxxl),
        ],
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
