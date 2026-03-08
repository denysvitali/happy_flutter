import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';

/// Features settings screen with experiment toggles.
class FeaturesSettingsScreen extends ConsumerWidget {
  const FeaturesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsNotifierProvider);
    final notifier =
        ref.read(settingsNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featuresTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          SettingsSection(
            title: 'Experiments',
            children: [
              SettingsToggleRow(
                icon: Icons.content_copy_rounded,
                title: 'Markdown Copy V2',
                subtitle:
                    'Use improved markdown copy format',
                value: settings.markdownCopyV2,
                onChanged: (v) =>
                    notifier.updateSetting(
                  'markdownCopyV2',
                  v,
                ),
              ),
              SettingsToggleRow(
                icon: Icons.density_small_rounded,
                title: 'Compact Mode',
                subtitle:
                    'Reduce spacing in chat messages',
                value: settings.compactSessionView,
                onChanged: (v) =>
                    notifier.updateSetting(
                  'compactSessionView',
                  v,
                ),
              ),
              SettingsToggleRow(
                icon: Icons.science_outlined,
                title: 'Experiments',
                subtitle:
                    'Enable experimental features',
                value: settings.experiments,
                onChanged: (v) =>
                    notifier.updateSetting(
                  'experiments',
                  v,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: 'Display',
            children: [
              SettingsToggleRow(
                icon: Icons.numbers_rounded,
                title: 'Show Line Numbers',
                subtitle:
                    'Display line numbers in code blocks',
                value: settings.showLineNumbers,
                onChanged: (v) =>
                    notifier.updateSetting(
                  'showLineNumbers',
                  v,
                ),
              ),
              SettingsToggleRow(
                icon: Icons.wrap_text_rounded,
                title: 'Wrap Lines in Diffs',
                subtitle:
                    'Wrap long lines in diff views',
                value: settings.wrapLinesInDiffs,
                onChanged: (v) =>
                    notifier.updateSetting(
                  'wrapLinesInDiffs',
                  v,
                ),
              ),
              SettingsToggleRow(
                icon: Icons.data_usage_rounded,
                title: 'Always Show Context Size',
                subtitle:
                    'Show context window usage',
                value: settings.alwaysShowContextSize,
                onChanged: (v) =>
                    notifier.updateSetting(
                  'alwaysShowContextSize',
                  v,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
