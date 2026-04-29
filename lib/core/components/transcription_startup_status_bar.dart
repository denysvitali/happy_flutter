import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../i18n/app_localizations.dart';
import '../providers/app_providers.dart';
import '../theme/app_tokens.dart';

class TranscriptionStartupStatusBar extends ConsumerWidget {
  const TranscriptionStartupStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(offlineDictationNotifierProvider);
    if (state.status == OfflineDictationStatus.idle) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (icon, text, foreground, background) = switch (state.status) {
      OfflineDictationStatus.initializing => (
        Icons.graphic_eq,
        context.l10n.transcriptionInitializing,
        colorScheme.primary,
        colorScheme.primaryContainer,
      ),
      OfflineDictationStatus.ready => (
        Icons.check_circle,
        context.l10n.transcriptionReady,
        colorScheme.onPrimaryContainer,
        colorScheme.primaryContainer,
      ),
      OfflineDictationStatus.error => (
        Icons.warning_amber_rounded,
        state.message ?? context.l10n.transcriptionUnavailable,
        colorScheme.onErrorContainer,
        colorScheme.errorContainer,
      ),
      OfflineDictationStatus.idle => (
        Icons.graphic_eq,
        '',
        colorScheme.onSurface,
        colorScheme.surface,
      ),
    };

    return Material(
      color: background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 32,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                if (state.isInitializing) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
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
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
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
