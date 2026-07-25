import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/code_viewer_theme.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/wire/wire_parsers.dart';
import 'message_detail_sheet.dart';

/// Tappable error card that shows a detail sheet on tap.
class ErrorMessageWidget extends StatelessWidget {
  const ErrorMessageWidget({required this.messageData, super.key});

  static const _jsonEncoder = JsonEncoder.withIndent('  ');

  final Map<String, dynamic> messageData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final errorType = messageData['errorType'] as String? ?? 'unknown';
    final errorMessage =
        messageData['errorMessage'] as String? ?? 'Unknown error';

    return GestureDetector(
      onTap: () => _showErrorDetailSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: cs.onErrorContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      errorType.replaceAll('_', ' '),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      errorMessage,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onErrorContainer.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: cs.onErrorContainer.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDetailSheet(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final code = context.codeViewerTheme;
    final l10n = context.l10n;
    final errorType = messageData['errorType'] as String? ?? 'unknown';
    final errorMessage =
        messageData['errorMessage'] as String? ?? 'Unknown error';
    final messageId = messageData['id'] as String?;
    final seq = messageData['seq'] as int?;
    final createdAt = messageData['createdAt'] as int?;
    final debugData = WireParsers.asMap(messageData['debugData']);

    final timestamp = createdAt != null
        ? DateTime.fromMillisecondsSinceEpoch(createdAt).toString()
        : 'Unknown';

    final jsonString = _jsonEncoder.convert({
      'errorType': errorType,
      'errorMessage': errorMessage,
      'messageId': messageId,
      'seq': seq,
      'createdAt': timestamp,
      'debugData': debugData,
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      errorType.replaceAll('_', ' '),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.error,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await setClipboardTextSafely(jsonString);
                      if (!ctx.mounted || !context.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.commonCopy),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l10n.commonCopy),
                  ),
                ],
              ),
            ),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
            // Error details
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // Error message
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      errorMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Metadata
                  DetailRow(
                    label: l10n.messageDetailMessageId,
                    value: messageId ?? l10n.commonNA,
                  ),
                  DetailRow(
                    label: l10n.messageDetailSeq,
                    value: seq?.toString() ?? l10n.commonNA,
                  ),
                  DetailRow(
                    label: l10n.messageDetailTimestamp,
                    value: timestamp,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Debug data
                  Text(
                    l10n.messageDetailDebugData,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: code.background,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: SelectableText(
                      debugData != null
                          ? _jsonEncoder.convert(debugData)
                          : 'No debug data',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: AppFontSize.sm,
                        color: code.foreground,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
