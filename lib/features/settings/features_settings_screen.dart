import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';

/// Features settings screen - Experiments toggles
class FeaturesSettingsScreen extends ConsumerWidget {
  const FeaturesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featuresTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(
            context,
            l10n.featuresExperimentalTitle,
          ),
          _buildToggle(
            context: context,
            title: l10n.featuresExperimentalTitle,
            subtitle: settings.experiments
                ? 'Enabled'
                : 'Disabled - Try new features',
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
            title: l10n.featuresEnhancedSessionWizard,
            subtitle: l10n.featuresEnhancedSessionWizardDesc,
            value: settings.useEnhancedSessionWizard,
            onChanged: (value) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting(
                    'useEnhancedSessionWizard',
                    value,
                  );
            },
          ),
          const SizedBox(height: 8),
          _buildToggle(
            context: context,
            title: l10n.featuresHideInactiveSessions,
            subtitle: l10n.featuresHideInactiveSessionsDesc,
            value: settings.hideInactiveSessions,
            onChanged: (value) {
              ref
                  .read(settingsNotifierProvider.notifier)
                  .updateSetting('hideInactiveSessions', value);
            },
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Display'),
          _buildToggle(
            context: context,
            title: l10n.featuresMarkdownCopyV2,
            subtitle: l10n.featuresMarkdownCopyV2Desc,
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
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
