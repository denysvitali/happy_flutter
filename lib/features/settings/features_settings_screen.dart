import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';

/// Features settings screen - Experiments toggles
class FeaturesSettingsScreen extends ConsumerWidget {
  const FeaturesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Features'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Experimental Features'),
          _buildToggle(
            context: context,
            title: 'Experimental Features',
            subtitle:
                settings.experiments ? 'Enabled' : 'Disabled - Try new features',
            value: settings.experiments,
            onChanged: (value) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('experiments', value);
            },
          ),
          const SizedBox(height: 8),
          _buildToggle(
            context: context,
            title: 'Enhanced Session Wizard',
            subtitle: 'Use the improved session creation flow',
            value: settings.useEnhancedSessionWizard,
            onChanged: (value) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('useEnhancedSessionWizard', value);
            },
          ),
          const SizedBox(height: 8),
          _buildToggle(
            context: context,
            title: 'Hide Inactive Sessions',
            subtitle: 'Hide sessions that have not been used recently',
            value: settings.hideInactiveSessions,
            onChanged: (value) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('hideInactiveSessions', value);
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Display'),
          _buildToggle(
            context: context,
            title: 'Markdown Copy V2',
            subtitle: 'Use improved markdown copying',
            value: settings.markdownCopyV2,
            onChanged: (value) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('markdownCopyV2', value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildToggle(
      {required BuildContext context,
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return Card(
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
