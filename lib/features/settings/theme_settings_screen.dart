import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/app_card.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/theme_helper.dart';

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
        padding: AppScreenPadding.settings,
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                _buildThemeOption(
                  context: context,
                  title: l10n.appearanceThemeAdaptive,
                  subtitle: l10n.appearanceThemeAdaptiveDesc,
                  icon: Icons.brightness_auto,
                  isSelected: settings.themeMode == 'adaptive',
                  onTap: () =>
                      _changeTheme(context, ref, 'adaptive'),
                ),
                _divider(context),
                _buildThemeOption(
                  context: context,
                  title: l10n.appearanceThemeLight,
                  subtitle: l10n.appearanceThemeLightDesc,
                  icon: Icons.light_mode,
                  isSelected: settings.themeMode == 'light',
                  onTap: () =>
                      _changeTheme(context, ref, 'light'),
                ),
                _divider(context),
                _buildThemeOption(
                  context: context,
                  title: l10n.appearanceThemeDark,
                  subtitle: l10n.appearanceThemeDarkDesc,
                  icon: Icons.dark_mode,
                  isSelected: settings.themeMode == 'dark',
                  onTap: () =>
                      _changeTheme(context, ref, 'dark'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _buildCurrentThemePreview(context),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: AppBorder.hairline,
      indent: AppSpacing.lg + 36 + AppSpacing.md,
      endIndent: 0,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }

  void _changeTheme(
    BuildContext context,
    WidgetRef ref,
    String themeMode,
  ) {
    ref
        .read(settingsNotifierProvider.notifier)
        .updateSetting('themeMode', themeMode);

    AppThemeMode.fromString(themeMode)
        .applySystemChromeWithContext(context);

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
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isSelected
            ? cs.primary.withValues(alpha: AppOpacity.faint)
            : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius:
                    BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected
                    ? cs.onPrimaryContainer
                    : cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: cs.primary,
                size: AppSpacing.xl,
              )
            else
              Icon(
                Icons.chevron_right,
                color: cs.onSurface.withValues(
                  alpha: AppOpacity.medium,
                ),
                size: AppSpacing.xl,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentThemePreview(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            l10n.appearanceThemePreview.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        AppCard(
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    isDark
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    color: cs.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    isDark
                        ? l10n.appearanceThemeDarkModeActive
                        : l10n
                            .appearanceThemeLightModeActive,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                height: AppTouchTarget.min,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius:
                      BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: cs.outlineVariant,
                  ),
                ),
                child: Center(
                  child: Text(
                    l10n.appearanceThemeSampleContent,
                    style: TextStyle(color: cs.onSurface),
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
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          AppRadius.sm,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          l10n.appearanceThemeColorPrimary,
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
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
                        color: cs.secondaryContainer,
                        borderRadius: BorderRadius.circular(
                          AppRadius.sm,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          l10n.appearanceThemeColorSecondary,
                          style: TextStyle(
                            color: cs.onSecondaryContainer,
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
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
          ),
          child: Text(
            l10n.appearanceThemeBasedOnDevice(
              isDark ? 'dark' : 'light',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
