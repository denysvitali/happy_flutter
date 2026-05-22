import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/components/app_card.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/providers/app_providers.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/theme_helper.dart';
import 'widgets/inline_theme_picker.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(
      settingsNotifierProvider.select((s) => s.themeMode),
    );
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appearanceTheme),
      ),
      body: ListView(
        padding: AppScreenPadding.settings,
        children: [
          // ── Visual theme preview cards ──────────────────────────────
          InlineThemePicker(
            currentMode: themeMode,
            onChanged: (mode) => _changeTheme(context, ref, mode),
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
