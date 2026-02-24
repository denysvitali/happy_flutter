import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';

/// Features settings screen
class FeaturesSettingsScreen extends ConsumerStatefulWidget {
  const FeaturesSettingsScreen({super.key});

  @override
  ConsumerState<FeaturesSettingsScreen> createState() =>
      _FeaturesSettingsScreenState();
}

class _FeaturesSettingsScreenState
    extends ConsumerState<FeaturesSettingsScreen> {
  bool _showAdvanced = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(settingsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.featuresTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          // Advanced section - collapsed by default
          _buildCollapsibleSectionHeader(
            context: context,
            title: 'Advanced',
            isExpanded: _showAdvanced,
            onToggle: () => setState(() => _showAdvanced = !_showAdvanced),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.sm),
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
        ],
      ),
    );
  }

  Widget _buildCollapsibleSectionHeader({
    required BuildContext context,
    required String title,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            AnimatedRotation(
              turns: isExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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
