import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/logger_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../dart_version.dart';

/// Developer screen - Debug tools (10x click to enable)
class DeveloperScreen extends ConsumerStatefulWidget {
  const DeveloperScreen({super.key});

  @override
  ConsumerState<DeveloperScreen> createState() => _DeveloperScreenState();
}

class _DeveloperScreenState extends ConsumerState<DeveloperScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _packageInfo = info);
    }
  }

  /// Flutter SDK version — no runtime API available.
  static const String _flutterVersion = '3.38.7';

  String get _dartVersion => getDartVersion();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDeveloperMode = ref.watch(
      settingsNotifierProvider.select((s) => s.developerModeEnabled),
    );
    final isToolCallDebug = ref.watch(
      settingsNotifierProvider.select((s) => s.toolCallDebugEnabled),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.developerTitle)),
      body: ListView(
        padding: AppScreenPadding.settings,
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
                      .read(settingsNotifierProvider.notifier)
                      .updateSetting('developerModeEnabled', value);
                },
              ),
            ],
          ),
          if (isDeveloperMode) ...[
            const SizedBox(height: AppSpacing.lg),
            SettingsSection(
              title: l10n.developerSectionDebugTools,
              children: [
                SettingsToggleRow(
                  icon: Icons.handyman,
                  title: 'Tool Call Debug',
                  subtitle: isToolCallDebug
                      ? 'Tool calls render as raw JSON'
                      : 'Render every tool call as raw JSON',
                  value: isToolCallDebug,
                  onChanged: (value) {
                    ref
                        .read(settingsNotifierProvider.notifier)
                        .updateSetting('toolCallDebugEnabled', value);
                  },
                ),
                SettingsNavRow(
                  icon: Icons.network_check,
                  title: l10n.developerNetworkInspector,
                  subtitle: l10n.developerNetworkInspectorDesc,
                  onTap: () => context.push('/settings/developer/network'),
                ),
                SettingsNavRow(
                  icon: Icons.battery_charging_full,
                  title: 'Power Diagnostics',
                  subtitle:
                      'Track lifecycle, socket, HTTP, sync, and retry activity',
                  onTap: () => context.push('/settings/developer/power'),
                ),
                SettingsNavRow(
                  icon: Icons.terminal,
                  title: l10n.settingsLogs,
                  subtitle: l10n.developerLogsDesc,
                  onTap: () => context.push('/settings/developer/logs'),
                ),
                SettingsNavRow(
                  icon: Icons.security,
                  title: l10n.developerEncryptionDebug,
                  subtitle: l10n.developerEncryptionDebugDesc,
                  onTap: () => context.push('/settings/developer/encryption'),
                ),
                SettingsNavRow(
                  icon: Icons.history,
                  title: l10n.developerSessionDebug,
                  subtitle: l10n.developerSessionDebugDesc,
                  onTap: () => context.push('/settings/developer/session'),
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
                  subtitle: l10n.developerTestNotificationsDesc,
                  onTap: () =>
                      context.push('/settings/developer/notifications'),
                ),
                SettingsNavRow(
                  icon: Icons.bug_report,
                  title: l10n.developerTestSentryException,
                  subtitle: l10n.developerTestSentryExceptionDesc,
                  onTap: () async {
                    try {
                      throw StateError('Sentry test exception');
                    } catch (e, st) {
                      logger.info('[Sentry] test exception capture started');
                      final eventId =
                          await Sentry.captureException(
                            e,
                            stackTrace: st,
                          ).timeout(
                            const Duration(seconds: 12),
                            onTimeout: () {
                              logger.warning(
                                '[Sentry] test exception capture timed out',
                              );
                              return const SentryId.empty();
                            },
                          );
                      if (eventId == const SentryId.empty()) {
                        logger.warning(
                          '[Sentry] test exception capture returned empty id',
                        );
                      } else {
                        logger.info(
                          '[Sentry] test exception captured id=$eventId',
                        );
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(
                                context,
                              ).developerSentToSentry('$eventId'),
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsSection(
              title: l10n.settingsAccountDangerZone,
              danger: true,
              children: [
                SettingsNavRow(
                  icon: Icons.error,
                  title: l10n.developerTestSentryUnhandled,
                  subtitle: l10n.developerTestSentryUnhandledDesc,
                  onTap: () => _confirmUnhandledSentryTest(context),
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
                  subtitle: l10n.developerResetSettingsDesc,
                  onTap: () => _resetSettings(context, ref),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            SettingsSection(
              title: l10n.developerSectionSync,
              children: [
                SettingsNavRow(
                  icon: Icons.sync,
                  title: l10n.developerForceSyncSettings,
                  subtitle: l10n.developerForceSyncSettingsDesc,
                  onTap: () => _forceSyncSettings(context, ref),
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
                  subtitle: _packageInfo?.version ?? '—',
                ),
                SettingsRow(
                  icon: Icons.numbers,
                  title: l10n.developerBuildNumber,
                  subtitle: _packageInfo?.buildNumber ?? '—',
                ),
                SettingsRow(
                  icon: Icons.flutter_dash,
                  title: l10n.developerFlutterVersion,
                  subtitle: _flutterVersion,
                ),
                SettingsRow(
                  icon: Icons.code,
                  title: l10n.developerDartVersion,
                  subtitle: _dartVersion,
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

  void _confirmUnhandledSentryTest(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final l10nDialog = AppLocalizations.of(context);
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(l10nDialog.developerTestSentryUnhandled),
          content: Text(l10nDialog.developerTestSentryUnhandledDesc),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10nDialog.commonCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(context);
                throw StateError('Sentry unhandled test error');
              },
              child: Text(l10nDialog.developerTestSentryUnhandled),
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
                backgroundColor: Theme.of(context).colorScheme.error,
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

  void _forceSyncSettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        final l10nDialog = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10nDialog.developerForceSyncSettings),
          content: Text(l10nDialog.developerForceSyncSettingsConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10nDialog.commonCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await sync.settingsSync.invalidateAndAwait();
                  if (context.mounted) {
                    ref.read(settingsNotifierProvider.notifier).loadFromSync();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          ).developerForceSyncSettingsSuccess,
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppLocalizations.of(
                            context,
                          ).developerForceSyncSettingsError,
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(l10nDialog.developerForceSyncSettingsAction),
            ),
          ],
        );
      },
    );
  }
}
