import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/wire_parsers.dart';

// ---------------------------------------------------------------------------
// Message detail bottom sheet (tap on bot message)
// ---------------------------------------------------------------------------

/// Shows a bottom sheet with model, permission mode and timestamp details
/// for a bot message.
void showMessageDetailSheet(
  BuildContext context,
  Map<String, dynamic> messageData,
) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final l10n = AppLocalizations.of(context);

  // meta may be directly on the message or inside the 'raw' decrypted record.
  final raw = WireParsers.asMap(messageData['raw']);
  final meta = WireParsers.asMap(messageData['meta'])
      ?? WireParsers.asMap(raw?['meta']);
  final model = meta?['model'] as String?
      ?? messageData['model'] as String?;
  final permissionMode = meta?['permissionMode'] as String?;
  final createdAt = messageData['createdAt'] as int?;

  final hasDetails = model != null || permissionMode != null;

  // Capture now once when the sheet is opened, not on every rebuild.
  final now = DateTime.now();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.xl),
      ),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.sm,
          bottom: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Text(
                l10n.messageDetailDetails,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!hasDetails)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Text(
                  l10n.messageDetailNoDetails,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            if (model != null)
              _MessageInfoRow(
                icon: Icons.auto_awesome_outlined,
                label: l10n.messageDetailModel,
                value: model,
              ),
            if (permissionMode != null)
              _MessageInfoRow(
                icon: Icons.shield_outlined,
                label: l10n.messageDetailPermission,
                value: permissionMode,
              ),
            if (createdAt != null)
              _MessageInfoRow(
                icon: Icons.access_time_outlined,
                label: l10n.messageDetailSent,
                value: _formatTimestamp(createdAt, now),
              ),
          ],
        ),
      ),
    ),
  );
}

String _formatTimestamp(int milliseconds, DateTime now) {
  final dt = DateTime.fromMillisecondsSinceEpoch(milliseconds);
  final diff = now.difference(dt);

  final timeStr =
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  if (diff.inDays == 0) return 'Today at $timeStr';
  if (diff.inDays == 1) return 'Yesterday at $timeStr';
  return '${dt.day}/${dt.month}/${dt.year} at $timeStr';
}

// ---------------------------------------------------------------------------
// Raw markdown bottom sheet (long-press to copy)
// ---------------------------------------------------------------------------

/// Shows a bottom sheet with selectable raw markdown text
/// and a copy-all button. This provides a reliable way to
/// copy message content on Android where SelectionArea can
/// be unreliable.
void showRawMarkdownSheet(BuildContext context, String markdown) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final l10n = context.l10n;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg),
      ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.chatCopyMessage,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await setClipboardTextSafely(markdown);
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
          Divider(
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
          // Selectable content
          Expanded(
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                SelectableText(
                  markdown,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.md,
                    height: 1.5,
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

// ---------------------------------------------------------------------------
// Shared row widgets
// ---------------------------------------------------------------------------

class _MessageInfoRow extends StatelessWidget {
  const _MessageInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A two-column label/value row used in detail sheets.
class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
