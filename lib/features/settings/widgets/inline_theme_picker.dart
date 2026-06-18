import 'package:flutter/material.dart';

import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Inline theme picker showing three visual preview cards (Adaptive, Light,
/// Dark). Each card renders a tiny fake AppBar and two mock message bubbles
/// tinted to that theme's palette. The selected card gets an accent border.
class InlineThemePicker extends StatelessWidget {
  const InlineThemePicker({
    required this.currentMode,
    required this.onChanged,
    super.key,
  });

  final String currentMode;
  final ValueChanged<String> onChanged;

  static const _modes = [
    ('adaptive', 'Auto'),
    ('light', 'Light'),
    ('dark', 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: _modes.map((m) {
        final selected = m.$1 == currentMode;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
            ),
            child: _ThemePreviewCard(
              mode: m.$1,
              label: m.$2,
              isSelected: selected,
              accentColor: cs.primary,
              onTap: () => onChanged(m.$1),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Preview card ─────────────────────────────────────────────────────────────

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.mode,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final String mode;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  /// Returns whether to render this card in dark colours.
  /// Adaptive mirrors the host platform brightness.
  bool _isDark(BuildContext context) {
    return switch (mode) {
      'dark' => true,
      'light' => false,
      _ =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final appCs = dark
        ? AppColorScheme.dark()
        : AppColorScheme.light();

    // Surface colours for the fake preview — these ARE the theme being
    // shown, so they must stay as raw hexes (replacing them with
    // Theme.of(context).colorScheme would render the picker's own
    // colours in every card).
    final bgColor = dark
        ? const Color(0xFF0F1117)
        : const Color(0xFFF8FAFF);
    final surfaceColor = dark
        ? const Color(0xFF1A1D27)
        : const Color(0xFFFFFFFF);
    final appBarColor = dark
        ? const Color(0xFF1A1D27)
        : const Color(0xFFFFFFFF);
    final onSurface = dark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF1E293B);

    // Chrome colours for the picker card itself (NOT the preview):
    // unselected border and unselected label follow the live M3 scheme
    // so the picker adapts to whichever app theme the user is in.
    final cs = Theme.of(context).colorScheme;
    final unselectedBorder =
        cs.outlineVariant.withValues(alpha: AppOpacity.subtle);
    final unselectedLabel = cs.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDuration.fast,
        curve: AppCurve.standard,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected
                ? accentColor
                : unselectedBorder,
            width: isSelected ? AppBorder.thick : AppBorder.thin,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(
                      alpha: AppOpacity.subtle,
                    ),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(AppRadius.md - 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Fake mini AppBar ───────────────────────────
              _MiniAppBar(
                bgColor: appBarColor,
                onSurface: onSurface,
                mode: mode,
              ),
              // ── Chat preview body ──────────────────────────
              Container(
                color: bgColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    // Assistant bubble (left-aligned)
                    _MiniMessageBubble(
                      isUser: false,
                      bubbleColor: appCs.bubbleAssistant,
                      textColor: appCs.bubbleAssistantText,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // User bubble (right-aligned)
                    _MiniMessageBubble(
                      isUser: true,
                      bubbleColor: appCs.bubbleUser,
                      textColor: appCs.bubbleUserText,
                    ),
                  ],
                ),
              ),
              // ── Label + selection checkmark ────────────────
              Container(
                color: surfaceColor,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.xs,
                  horizontal: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: AppFontSize.xs,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isSelected
                            ? accentColor
                            : unselectedLabel,
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: accentColor,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mini fake AppBar ─────────────────────────────────────────────────────────

class _MiniAppBar extends StatelessWidget {
  const _MiniAppBar({
    required this.bgColor,
    required this.onSurface,
    required this.mode,
  });

  final Color bgColor;
  final Color onSurface;
  final String mode;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgColor,
      height: 22,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
      ),
      child: Row(
        children: [
          // Back-button stub
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: onSurface.withValues(
                alpha: AppOpacity.medium,
              ),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Title bar stub
          Expanded(
            child: Container(
              height: 5,
              decoration: BoxDecoration(
                color: onSurface.withValues(
                  alpha: AppOpacity.soft,
                ),
                borderRadius:
                    BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Mode icon
          Icon(
            switch (mode) {
              'light' => Icons.light_mode_outlined,
              'dark' => Icons.dark_mode_outlined,
              _ => Icons.brightness_auto_outlined,
            },
            size: 10,
            color: onSurface.withValues(
              alpha: AppOpacity.medium,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Mini message bubble ──────────────────────────────────────────────────────

class _MiniMessageBubble extends StatelessWidget {
  const _MiniMessageBubble({
    required this.isUser,
    required this.bubbleColor,
    required this.textColor,
  });

  final bool isUser;
  final Color bubbleColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 60),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(
              isUser ? AppRadius.md : AppRadius.xxs,
            ),
            topRight: Radius.circular(
              isUser ? AppRadius.xxs : AppRadius.md,
            ),
            bottomLeft: const Radius.circular(AppRadius.md),
            bottomRight: const Radius.circular(AppRadius.md),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First text line stub
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: textColor.withValues(
                  alpha: AppOpacity.high,
                ),
                borderRadius:
                    BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            // Second shorter line stub
            FractionallySizedBox(
              widthFactor: 0.65,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: textColor.withValues(
                    alpha: AppOpacity.half,
                  ),
                  borderRadius:
                      BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
