import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_scroll_behavior.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/wire/wire_parsers.dart';

/// Maximum raw message content laid out in one selectable text widget.
/// Keeping the reader paged prevents a very large message from exhausting
/// the UI isolate's text-layout stack after the timeline safely truncates it.
const int _rawMarkdownPageSize = 12 * 1024;

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
  final meta =
      WireParsers.asMap(messageData['meta']) ?? WireParsers.asMap(raw?['meta']);
  // Prefer the per-message model reported by Claude Code
  // (messageData['model'], parsed from the assistant payload) over the
  // session-level meta.model, which is a user-supplied label and can be
  // stale or unrelated to the actual inference model.
  final model = messageData['model'] as String? ?? meta?['model'] as String?;
  final permissionMode = meta?['permissionMode'] as String?;
  final createdAt = messageData['createdAt'] as int?;

  final hasDetails = model != null || permissionMode != null;

  // Capture now once when the sheet is opened, not on every rebuild.
  final now = DateTime.now();

  final messageId = messageData['id']?.toString();
  final messageText = (messageData['content'] ?? messageData['text'] ?? '')
      .toString();
  final canSpeak =
      !kIsWeb && messageText.trim().isNotEmpty && messageId != null;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
            if (canSpeak)
              _SpeakRow(
                messageId: messageId,
                messageText: messageText,
                onTriggered: () => Navigator.of(ctx).maybePop(),
              ),
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
              MessageInfoRow(
                icon: Icons.auto_awesome_outlined,
                label: l10n.messageDetailModel,
                value: model,
              ),
            if (permissionMode != null)
              MessageInfoRow(
                icon: Icons.shield_outlined,
                label: l10n.messageDetailPermission,
                value: permissionMode,
              ),
            if (createdAt != null)
              MessageInfoRow(
                icon: Icons.access_time_outlined,
                label: l10n.messageDetailSent,
                value: formatMessageTimestamp(createdAt, now),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Formats a message timestamp relative to [now] ("Today at 14:03").
String formatMessageTimestamp(int milliseconds, DateTime now) {
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
void showRawMarkdownSheet(
  BuildContext context,
  String markdown, {
  String? title,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final l10n = context.l10n;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      // Start tall so a finger drag on the text scrolls the content
      // immediately, instead of being captured by the sheet's own
      // expand-on-overscroll (which used to start at 0.55 and made the
      // bottom of any long message feel "unscrollable").
      initialChildSize: 0.9,
      minChildSize: 0.5,
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
                    title ?? l10n.chatCopyMessage,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await setClipboardTextSafely(markdown);
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
          // Selectable content
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.lg),
              // SelectableText nests a zero-extent Scrollable that, under the
              // app's bouncing/always-scrollable behavior, steals the vertical
              // drag and springs back to the top — so the pane above never
              // scrolls. Clamping its descendants lets the drag fall through.
              child: ScrollConfiguration(
                behavior: const NeutralizeInnerScrollBehavior(),
                child: _PagedRawMarkdown(
                  markdown: markdown,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: AppFontSize.md,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Selectable raw markdown reader that lays out one bounded page at a time.
/// Copy still receives the complete source through [markdown], while the
/// visible reader never constructs a 300k-character paragraph.
class _PagedRawMarkdown extends StatefulWidget {
  const _PagedRawMarkdown({required this.markdown, required this.style});

  final String markdown;
  final TextStyle? style;

  @override
  State<_PagedRawMarkdown> createState() => _PagedRawMarkdownState();
}

class _PagedRawMarkdownState extends State<_PagedRawMarkdown> {
  int _page = 0;

  int get _pageCount =>
      (widget.markdown.length / _rawMarkdownPageSize).ceil().clamp(1, 1 << 20);

  String get _pageText {
    final start = _page * _rawMarkdownPageSize;
    final end = (start + _rawMarkdownPageSize).clamp(0, widget.markdown.length);
    return widget.markdown.substring(start, end);
  }

  @override
  void didUpdateWidget(_PagedRawMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markdown != widget.markdown) {
      _page = _page.clamp(0, _pageCount - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageCount = _pageCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(_pageText, style: widget.style),
        if (pageCount > 1)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: _page == 0 ? null : () => setState(() => _page--),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${_page + 1} / $pageCount'),
              IconButton(
                tooltip: 'Next page',
                onPressed: _page + 1 >= pageCount
                    ? null
                    : () => setState(() => _page++),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared row widgets
// ---------------------------------------------------------------------------

/// Icon + label + value row shared by the message detail sheet and the
/// long-press focus card.
class MessageInfoRow extends StatelessWidget {
  const MessageInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
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

/// "Speak this message" / "Stop speaking" row shown at the top of the
/// detail sheet. Mirrors the play state of [TtsService] so tapping
/// while the message is already playing stops it.
class _SpeakRow extends ConsumerWidget {
  const _SpeakRow({
    required this.messageId,
    required this.messageText,
    required this.onTriggered,
  });

  final String messageId;
  final String messageText;
  final VoidCallback onTriggered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<String?>(
      valueListenable: TtsService().currentToken,
      builder: (context, currentToken, _) {
        final isPlaying = currentToken == messageId;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () {
              if (isPlaying) {
                TtsService().stop();
              } else {
                final settings = ref.read(settingsNotifierProvider);
                TtsService().speak(
                  messageText,
                  token: messageId,
                  useOffline: settings.ttsUseOffline,
                  offlineVoiceId: settings.ttsVoiceId,
                );
              }
              onTriggered();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                      size: 18,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      isPlaying ? 'Stop speaking' : 'Speak this message',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A two-column label/value row used in detail sheets.
class DetailRow extends StatelessWidget {
  const DetailRow({required this.label, required this.value, super.key});

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
