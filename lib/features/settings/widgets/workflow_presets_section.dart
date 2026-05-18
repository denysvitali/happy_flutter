import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';

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
    return SettingsSection(
      title: 'Workflow presets',
      description:
          'Presets update existing app settings and can be adjusted later.',
      children: [
        for (final preset in _workflowPresets)
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

    return SettingsRow(
      icon: preset.icon,
      iconColor: active ? AppColors.success : null,
      title: preset.title,
      subtitle: active ? '${preset.subtitle} - Active' : preset.subtitle,
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
    for (final entry in preset.values.entries) {
      await notifier.updateSetting<dynamic>(entry.key, entry.value);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${preset.title} preset applied')));
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

const _workflowPresets = [
  _WorkflowPreset(
    title: 'Focus',
    subtitle: 'Quiet chat, compact sessions, unread-first navigation',
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
    title: 'Voice',
    subtitle: 'Speech on, inline context, classic session browsing',
    icon: Icons.record_voice_over,
    values: {
      'ttsEnabled': true,
      'viewInline': true,
      'hideToolCalls': false,
      'sessionsViewStyle': 'classic',
    },
  ),
  _WorkflowPreset(
    title: 'Low noise',
    subtitle: 'Hide tool chatter and inactive work by default',
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
    title: 'Debug',
    subtitle: 'Show internals, tool calls, todos, and developer logging',
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
