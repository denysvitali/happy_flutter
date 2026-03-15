import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/settings_section.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';

/// Features settings screen with feature toggles.
class FeaturesSettingsScreen extends ConsumerWidget {
  const FeaturesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.featuresTitle)),
      body: ListView(
        padding: AppScreenPadding.settings,
        children: [
          SettingsSection(
            title: l10n.featuresSectionExperiments,
            children: [
              SettingsToggleRow(
                icon: Icons.visibility_off_outlined,
                title: l10n.featuresHideInactiveSessions,
                subtitle: l10n.featuresHideInactiveSessionsDesc,
                value: settings.hideInactiveSessions,
                onChanged: (v) =>
                    notifier.updateSetting('hideInactiveSessions', v),
              ),
              SettingsToggleRow(
                icon: Icons.content_copy_rounded,
                title: l10n.featuresMarkdownCopyV2,
                subtitle: l10n.featuresMarkdownCopyV2Desc,
                value: settings.markdownCopyV2,
                onChanged: (v) =>
                    notifier.updateSetting('markdownCopyV2', v),
              ),
              SettingsToggleRow(
                icon: Icons.density_small_rounded,
                title: l10n.featuresCompactMode,
                subtitle: l10n.featuresCompactModeDesc,
                value: settings.compactSessionView,
                onChanged: (v) =>
                    notifier.updateSetting('compactSessionView', v),
              ),
              SettingsToggleRow(
                icon: Icons.science_outlined,
                title: l10n.featuresExperiments,
                subtitle: l10n.featuresExperimentsDesc,
                value: settings.experiments,
                onChanged: (v) =>
                    notifier.updateSetting('experiments', v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SettingsSection(
            title: l10n.featuresSectionDisplay,
            children: [
              SettingsToggleRow(
                icon: Icons.numbers_rounded,
                title: l10n.featuresShowLineNumbers,
                subtitle: l10n.featuresShowLineNumbersDesc,
                value: settings.showLineNumbers,
                onChanged: (v) =>
                    notifier.updateSetting('showLineNumbers', v),
              ),
              SettingsToggleRow(
                icon: Icons.wrap_text_rounded,
                title: l10n.featuresWrapLinesInDiffs,
                subtitle: l10n.featuresWrapLinesInDiffsDesc,
                value: settings.wrapLinesInDiffs,
                onChanged: (v) =>
                    notifier.updateSetting('wrapLinesInDiffs', v),
              ),
              SettingsToggleRow(
                icon: Icons.data_usage_rounded,
                title: l10n.featuresAlwaysShowContextSize,
                subtitle: l10n.featuresAlwaysShowContextSizeDesc,
                value: settings.alwaysShowContextSize,
                onChanged: (v) =>
                    notifier.updateSetting('alwaysShowContextSize', v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
