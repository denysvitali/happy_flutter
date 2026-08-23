import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/snack.dart';

class WorkflowPresetsSection extends ConsumerWidget {
  const WorkflowPresetsSection({
    required this.viewInline,
    required this.hideToolCalls,
    required this.expandTodos,
    required this.showFlavorIcons,
    required this.ttsEnabled,
    required this.developerModeEnabled,
    required this.toolCallDebugEnabled,
    required this.sessionsViewStyle,
    required this.compactSessionView,
    required this.hideInactiveSessions,
    super.key,
  });

  final bool viewInline;
  final bool hideToolCalls;
  final bool expandTodos;
  final bool showFlavorIcons;
  final bool ttsEnabled;
  final bool developerModeEnabled;
  final bool toolCallDebugEnabled;
  final String sessionsViewStyle;
  final bool compactSessionView;
  final bool hideInactiveSessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SettingsSection(
      title: l10n.workflowPresetsTitle,
      description: l10n.workflowPresetsDescription,
      children: [
        for (final preset in _workflowPresets(l10n))
          _buildPresetRow(context, ref, preset),
      ],
    );
  }

  Widget _buildPresetRow(
    BuildContext context,
    WidgetRef ref,
    _WorkflowPreset preset,
  ) {
    final active = _presetMatches(preset);
    final l10n = AppLocalizations.of(context);

    return SettingsRow(
      icon: preset.icon,
      iconColor: active ? AppColors.success : null,
      title: preset.title,
      subtitle: active
          ? '${preset.subtitle} ${l10n.workflowPresetActiveSuffix}'
          : preset.subtitle,
      trailing: Icon(
        active ? Icons.check_circle : Icons.flash_on_outlined,
        color: active
            ? AppColors.success
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: () => _applyPreset(context, ref, preset),
    );
  }

  bool _presetMatches(_WorkflowPreset preset) {
    for (final entry in preset.values.entries) {
      final current = switch (entry.key) {
        'viewInline' => viewInline,
        'hideToolCalls' => hideToolCalls,
        'expandTodos' => expandTodos,
        'showFlavorIcons' => showFlavorIcons,
        'ttsEnabled' => ttsEnabled,
        'developerModeEnabled' => developerModeEnabled,
        'toolCallDebugEnabled' => toolCallDebugEnabled,
        'sessionsViewStyle' => sessionsViewStyle,
        'compactSessionView' => compactSessionView,
        'hideInactiveSessions' => hideInactiveSessions,
        _ => null,
      };
      if (current != entry.value) return false;
    }
    return true;
  }

  Future<void> _applyPreset(
    BuildContext context,
    WidgetRef ref,
    _WorkflowPreset preset,
  ) async {
    final notifier = ref.read(settingsNotifierProvider.notifier);
    await notifier.applySettings(Map<String, dynamic>.from(preset.values));
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    context.showSnack('${preset.title} ${l10n.workflowPresetAppliedSnack}');
  }
}

class _WorkflowPreset {
  const _WorkflowPreset({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.values,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Map<String, Object> values;
}

List<_WorkflowPreset> _workflowPresets(AppLocalizations l10n) => [
  _WorkflowPreset(
    title: l10n.workflowPresetFocusTitle,
    subtitle: l10n.workflowPresetFocusSubtitle,
    icon: Icons.center_focus_strong,
    values: {
      'hideToolCalls': true,
      'expandTodos': false,
      'ttsEnabled': false,
      'compactSessionView': true,
      'hideInactiveSessions': true,
      'sessionsViewStyle': 'unread_focus',
    },
  ),
  _WorkflowPreset(
    title: l10n.workflowPresetVoiceTitle,
    subtitle: l10n.workflowPresetVoiceSubtitle,
    icon: Icons.record_voice_over,
    values: {
      'ttsEnabled': true,
      'viewInline': true,
      'hideToolCalls': false,
      'sessionsViewStyle': 'mission_control',
    },
  ),
  _WorkflowPreset(
    title: l10n.workflowPresetLowNoiseTitle,
    subtitle: l10n.workflowPresetLowNoiseSubtitle,
    icon: Icons.notifications_paused_outlined,
    values: {
      'hideToolCalls': true,
      'expandTodos': false,
      'showFlavorIcons': false,
      'compactSessionView': true,
      'hideInactiveSessions': true,
    },
  ),
  _WorkflowPreset(
    title: l10n.workflowPresetDebugTitle,
    subtitle: l10n.workflowPresetDebugSubtitle,
    icon: Icons.bug_report_outlined,
    values: {
      'developerModeEnabled': true,
      'toolCallDebugEnabled': true,
      'viewInline': true,
      'hideToolCalls': false,
      'expandTodos': true,
    },
  ),
];
