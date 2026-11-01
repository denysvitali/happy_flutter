import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_localizations.dart';
import 'app_badge.dart';
import '../providers/app_providers.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_circular_progress_indicator.dart';
import 'package:happy_flutter/core/theme/app_text.dart';

class TranscriptionStartupStatusBar extends ConsumerWidget {
  const TranscriptionStartupStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineDictationNotifierProvider);
    if (state.status == OfflineDictationStatus.idle) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final (icon, text, tone) = switch (state.status) {
      OfflineDictationStatus.initializing => (
        Icons.graphic_eq,
        context.l10n.transcriptionInitializing,
        AppBadgeTone.info,
      ),
      OfflineDictationStatus.ready => (
        Icons.check_circle,
        context.l10n.transcriptionReady,
        AppBadgeTone.success,
      ),
      OfflineDictationStatus.error => (
        Icons.warning_amber_rounded,
        state.message ?? context.l10n.transcriptionUnavailable,
        AppBadgeTone.danger,
      ),
      OfflineDictationStatus.idle => (
        Icons.graphic_eq,
        '',
        AppBadgeTone.neutral,
      ),
    };
    final colors = AppToneColors.of(context, tone);
    final foreground = colors.foreground;
    final background = colors.background;

    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: AppControlSize.md,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                if (state.isInitializing) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: AppCircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  ),
                ] else ...[
                  Icon(icon, size: 16, color: foreground),
                ],
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label(theme, foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
