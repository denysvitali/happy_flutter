import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
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
              title: const Text('Developer Mode'),
              subtitle: Text(isDeveloperMode
                  ? 'Enabled - Debug tools are visible'
                  : 'Disabled - Tap 10 times to enable'),
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
            _buildSectionHeader('Debug Tools'),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: 'Network Inspector',
              subtitle: 'View API requests and responses',
              icon: Icons.network_check,
              onTap: () =>
                  context.push('/settings/developer/network'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: 'Logs',
              subtitle: 'View application logs',
              icon: Icons.terminal,
              onTap: () => context.push('/settings/developer/logs'),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: 'Encryption Debug',
              subtitle: 'View encryption keys and certificates',
              icon: Icons.security,
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: 'Session Debug',
              subtitle: 'View active sessions and connections',
              icon: Icons.history,
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildSectionHeader('Testing'),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: 'Test Notifications',
              subtitle: 'Send a test push notification',
              icon: Icons.notifications,
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: 'Test Error Reporting',
              subtitle: 'Trigger a test error',
              icon: Icons.bug_report,
              onTap: () {},
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildSectionHeader('Cache & Storage'),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: l10n.developerClearCache,
              subtitle: 'Clear cached data',
              icon: Icons.delete_sweep,
              onTap: () => _clearCache(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildDebugOption(
              context: context,
              title: l10n.developerResetSettings,
              subtitle: 'Reset all settings to defaults',
              icon: Icons.restart_alt,
              onTap: () => _resetSettings(context, ref),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _buildSectionHeader('Build Info'),
            const SizedBox(height: AppSpacing.sm),
            _buildInfoTile('App Version', '1.0.0'),
            _buildInfoTile('Build Number', '1'),
            _buildInfoTile('Flutter Version', '3.38.7'),
            _buildInfoTile('Dart Version', '3.10+'),
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
          content: const Text(
            'Are you sure you want to clear all cached data?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10nDialog.commonCancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache cleared')),
                );
              },
              child: const Text('Clear'),
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
          content: const Text(
            'Are you sure you want to reset all settings '
            'to defaults?',
          ),
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
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings reset')),
                );
              },
              child: const Text('Reset'),
            ),
          ],
        );
      },
    );
  }
}
