import 'package:flutter/material.dart';

import '../../../core/components/settings_section.dart';
import '../../../core/theme/app_tokens.dart';

/// Inline theme picker showing three selectable chips for theme modes.
class InlineThemePicker extends StatelessWidget {
  const InlineThemePicker({
    required this.currentMode,
    required this.onChanged,
    super.key,
  });

  final String currentMode;
  final ValueChanged<String> onChanged;

  static const _modes = [
    ('adaptive', Icons.brightness_auto, 'Auto'),
    ('light', Icons.light_mode, 'Light'),
    ('dark', Icons.dark_mode, 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          SettingsIconContainer(icon: Icons.palette),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Row(
              children: _modes.map((m) {
                final selected = m.$1 == currentMode;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxxs,
                    ),
                    child: AnimatedContainer(
                      duration: AppDuration.fast,
                      curve: AppCurve.standard,
                      decoration: BoxDecoration(
                        color: selected
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AppRadius.sm,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppRadius.sm,
                        ),
                        child: InkWell(
                          onTap: () => onChanged(m.$1),
                          borderRadius: BorderRadius.circular(
                            AppRadius.sm,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    Icon(
                                      m.$2,
                                      size: 20,
                                      color: selected
                                          ? cs.onPrimaryContainer
                                          : cs.onSurfaceVariant,
                                    ),
                                    if (selected)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Icon(
                                          Icons.check_circle,
                                          size: 12,
                                          color: cs.primary,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(
                                  height: AppSpacing.xs,
                                ),
                                Text(
                                  m.$3,
                                  style: theme.textTheme.labelSmall
                                      ?.copyWith(
                                    color: selected
                                        ? cs.onPrimaryContainer
                                        : cs.onSurfaceVariant,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
