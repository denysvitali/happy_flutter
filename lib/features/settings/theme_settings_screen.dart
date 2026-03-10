import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appearanceTheme),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildThemeOption(
            context: context,
            title: l10n.appearanceThemeAdaptive,
            subtitle: l10n.appearanceThemeAdaptiveDesc,
            icon: Icons.brightness_auto,
            isSelected: settings.themeMode == 'adaptive',
            onTap: () => _changeTheme(context, ref, 'adaptive'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildThemeOption(
            context: context,
            title: l10n.appearanceThemeLight,
            subtitle: l10n.appearanceThemeLightDesc,
            icon: Icons.light_mode,
            isSelected: settings.themeMode == 'light',
            onTap: () => _changeTheme(context, ref, 'light'),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildThemeOption(
            context: context,
            title: l10n.appearanceThemeDark,
            subtitle: l10n.appearanceThemeDarkDesc,
            icon: Icons.dark_mode,
            isSelected: settings.themeMode == 'dark',
            onTap: () => _changeTheme(context, ref, 'dark'),
          ),
          const SizedBox(height: AppSpacing.xxl),
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
    AppThemeMode.fromString(themeMode).applySystemChromeWithContext(context);

    // Show feedback
    final l10n = AppLocalizations.of(context);
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
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentThemePreview(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.appearanceThemePreview,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      isDark
                          ? l10n.appearanceThemeDarkModeActive
                          : l10n.appearanceThemeLightModeActive,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  height: AppTouchTarget.min,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      l10n.appearanceThemeSampleContent,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: AppTouchTarget.min,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Center(
                          child: Text(
                            l10n.appearanceThemeColorPrimary,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Container(
                        height: AppTouchTarget.min,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Center(
                          child: Text(
                            l10n.appearanceThemeColorSecondary,
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
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.appearanceThemeBasedOnDevice(isDark ? 'dark' : 'light'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
