import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import '../../core/models/settings.dart';
import '../../core/providers/app_providers.dart';
import '../../core/utils/theme_helper.dart';

/// Theme settings screen - Adaptive/Light/Dark theme selection
///
/// This screen allows users to select their preferred theme mode:
/// - Adaptive: Follows the system-wide appearance settings
/// - Light: Always uses light theme
/// - Dark: Always uses dark theme
///
/// The selected theme is persisted to local storage and applied immediately.
class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appearanceTheme),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildThemeOption(
            context: context,
            title: l10n.appearanceThemeAdaptive,
            subtitle: l10n.appearanceThemeAdaptiveDesc,
            icon: Icons.brightness_auto,
            isSelected: settings.themeMode == 'adaptive',
            onTap: () => _changeTheme(context, ref, 'adaptive'),
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            context: context,
            title: l10n.appearanceThemeLight,
            subtitle: l10n.appearanceThemeLightDesc,
            icon: Icons.light_mode,
            isSelected: settings.themeMode == 'light',
            onTap: () => _changeTheme(context, ref, 'light'),
          ),
          const SizedBox(height: 8),
          _buildThemeOption(
            context: context,
            title: l10n.appearanceThemeDark,
            subtitle: l10n.appearanceThemeDarkDesc,
            icon: Icons.dark_mode,
            isSelected: settings.themeMode == 'dark',
            onTap: () => _changeTheme(context, ref, 'dark'),
          ),
          const SizedBox(height: 24),
          _buildCurrentThemePreview(context),
        ],
      ),
    );
  }

  void _changeTheme(
    BuildContext context,
    WidgetRef ref,
    String themeMode,
  ) {
    // Update the setting
    ref
        .read(settingsNotifierProvider.notifier)
        .updateSetting('themeMode', themeMode);

    // Apply system UI chrome style immediately
    final mode = AppThemeMode.fromString(themeMode);
    mode.applySystemChromeWithContext(context);

    // Show feedback
    final l10n = context.l10n;
    final message = switch (themeMode) {
      'light' => l10n.appearanceThemeApplied('Light'),
      'dark' => l10n.appearanceThemeApplied('Dark'),
      _ => l10n.appearanceThemeApplied('System'),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentThemePreview(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final isDark = brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preview',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isDark ? 'Dark mode active' : 'Light mode active',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Sample content',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Primary',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            'Secondary',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Based on your device\'s ${isDark ? 'dark' : 'light'} appearance setting.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
