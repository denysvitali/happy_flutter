import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/provider_usage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clipboard_utils.dart';

/// Modal bottom sheet that renders the raw provider response payload captured
/// by the usage API clients ([KimiUsageApi], [MiniMaxUsageApi], [ZaiUsageApi]).
///
/// The raw payload is delivered through [ProviderUsage.extra] under the keys
/// `raw_payload` (pretty) and `raw_payload_compact` (single-line). We prefer
/// the pretty form for display, but expose the compact form too for the copy
/// button so users can paste it straight into a bug report.
class ProviderPayloadDebugSheet extends StatelessWidget {
  const ProviderPayloadDebugSheet({
    required this.usage,
    super.key,
  });

  final ProviderUsage usage;

  static Future<void> show(BuildContext context, ProviderUsage usage) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => ProviderPayloadDebugSheet(usage: usage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;

    final extra = usage.extra;
    final pretty = extra['raw_payload'] as String?;
    final compact = extra['raw_payload_compact'] as String?;
    final endpoint = extra['endpoint'] as String?;
    final status = extra['status'];
    final requestUrl = extra['request_url'] as String?;
    final windowCount = extra['window_count'];

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: AppScreenPadding.standard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bug_report_outlined,
                    color: AppColors.warning,
                    size: AppSpacing.xl,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${_providerDisplayName(usage.type)} raw response',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonClose,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _MetadataRow(label: 'Account', value: usage.accountName ?? '—'),
              _MetadataRow(
                label: 'Type',
                value: usage.type.name,
              ),
              if (endpoint != null)
                _MetadataRow(label: 'Endpoint', value: endpoint),
              if (requestUrl != null)
                _MetadataRow(label: 'URL', value: requestUrl, monospace: true),
              if (status != null)
                _MetadataRow(
                  label: 'Status',
                  value: status.toString(),
                  valueColor: switch (status) {
                    200 => AppColors.success,
                    401 || 403 => colorScheme.error,
                    _ => null,
                  },
                ),
              if (windowCount is int)
                _MetadataRow(label: 'Windows parsed', value: '$windowCount'),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    'Payload',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: pretty == null && compact == null
                        ? null
                        : () async {
                            final text =
                                pretty ?? compact ?? '';
                            final result = await setClipboardTextSafely(text);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.success
                                      ? (result.truncated
                                            ? 'Copied (truncated)'
                                            : l10n.commonCopied)
                                      : l10n.textSelectionFailedToCopy,
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l10n.commonCopy),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: pretty != null
                      ? _SelectableJson(text: pretty)
                      : compact != null
                      ? _SelectableJson(text: compact)
                      : Center(
                          child: Text(
                            'No payload captured for this account yet. '
                            'Pull-to-refresh to retry.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.label,
    required this.value,
    this.monospace = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool monospace;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: monospace ? 'monospace' : null,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableJson extends StatelessWidget {
  const _SelectableJson({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: AppFontSize.sm,
            height: AppLineHeight.relaxed,
          ),
        ),
      ),
    );
  }
}

/// Returns the human-readable vendor name for [type].
String _providerDisplayName(ProviderUsageType type) {
  return switch (type) {
    ProviderUsageType.kimi => 'Kimi',
    ProviderUsageType.minimax => 'MiniMax',
    ProviderUsageType.zai => 'Z.AI',
    ProviderUsageType.grok => 'Grok',
    ProviderUsageType.qwen => 'Qwen',
    ProviderUsageType.claudeCode => 'Claude Code',
    ProviderUsageType.codex => 'Codex',
  };
}

/// Copies [text] using the system clipboard. Wrapped here so the bottom sheet
/// can stay free of utility imports.
@visibleForTesting
Future<void> copyTextForTest(String text) => Clipboard.setData(
      ClipboardData(text: text),
    );
