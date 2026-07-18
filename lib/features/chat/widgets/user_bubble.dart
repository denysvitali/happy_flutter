import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/pressable_card.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../markdown/markdown.dart';
import 'message_detail_sheet.dart';
import 'send_status_indicator.dart';

/// Extracts Anthropic `image` content blocks from a user message's `raw`
/// payload (present on optimistic rows and on server-decoded rows whose
/// content is a block array). Returns null when the message has no images.
List<Map<String, dynamic>>? extractUserImageBlocks(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final content = raw['content'];
  if (content is! List) return null;
  final blocks = content
      .whereType<Map<String, dynamic>>()
      .where((block) => block['type'] == 'image')
      .toList(growable: false);
  return blocks.isEmpty ? null : blocks;
}

/// Right-aligned speech bubble for user messages.
///
/// Uses primary color background with iMessage-style grouped radii.
class UserBubble extends StatelessWidget {
  const UserBubble({
    required this.text,
    super.key,
    this.imageBlocks,
    this.onOptionPress,
    this.sendStatus,
    this.onRetry,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
  });

  final String text;

  /// Anthropic image blocks attached to this message, if any.
  final List<Map<String, dynamic>>? imageBlocks;

  final void Function(String)? onOptionPress;

  /// `null` = confirmed (server-origin), `'sending'`, `'sent'`,
  /// `'failed'`.
  final String? sendStatus;
  final VoidCallback? onRetry;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  static const _full = Radius.circular(AppRadius.xl);
  static const _small = Radius.circular(AppRadius.xsm);

  String _truncateForLabel(String text) {
    const maxLength = 100;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = cs.primary;

    // Grouped radii: right side pinches for consecutive messages.
    final radius = BorderRadius.only(
      topLeft: _full,
      topRight: isFirstInGroup ? _full : _small,
      bottomLeft: _full,
      bottomRight: isLastInGroup ? _full : _small,
    );

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xxl,
          right: AppSpacing.sm,
          top: isFirstInGroup ? AppSpacing.xs : 1,
          bottom: isLastInGroup ? AppSpacing.xs : 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            PressableCard(
              onLongPress: () {
                HapticFeedback.heavyImpact();
                showRawMarkdownSheet(context, text);
              },
              pressedScale: 0.97,
              enableHaptics: false,
              duration: const Duration(milliseconds: 100),
              child: Semantics(
                label: 'User message: ${_truncateForLabel(text)}',
                button: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md + 2,
                    vertical: AppSpacing.sm + 2,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.80,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: color.withAlpha(40),
                        blurRadius: AppSpacing.sm,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (imageBlocks != null) ...[
                        for (final block in imageBlocks!)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: _UserImageThumb(block: block),
                          ),
                      ],
                      if (text.isNotEmpty)
                        MarkdownView(
                          markdown: text,
                          onOptionPress: onOptionPress,
                          textColor: cs.onPrimary,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (sendStatus != null)
              SendStatusIndicator(
                status: sendStatus!,
                onRetry: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

/// Inline thumbnail for an attached image inside a [UserBubble].
///
/// Base64 blocks render from memory; URL blocks (legacy markdown-image
/// sends) render from the network. Blocks whose base64 data was stripped
/// by the offline cache show a placeholder. Tapping opens a fullscreen
/// viewer with pinch zoom (same pattern as the session file viewer).
class _UserImageThumb extends StatelessWidget {
  const _UserImageThumb({required this.block});

  final Map<String, dynamic> block;

  static const double _maxThumbHeight = 220;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final source = block['source'];
    if (source is! Map<String, dynamic>) return const SizedBox.shrink();

    final sourceType = source['type'] as String?;
    final borderRadius = BorderRadius.circular(AppRadius.md);

    if (sourceType == 'base64') {
      final data = source['data'] as String? ?? '';
      if (data.isEmpty) {
        // Image bytes were stripped when the message landed in the
        // offline MMKV cache — the pixels are unrecoverable locally.
        return Container(
          height: 72,
          width: 160,
          decoration: BoxDecoration(
            color: cs.onPrimary.withValues(alpha: 0.12),
            borderRadius: borderRadius,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  size: 16,
                  color: cs.onPrimary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    l10n.chatImageNotCached,
                    style: TextStyle(
                      fontSize: AppFontSize.xs,
                      color: cs.onPrimary.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      final bytes = base64Decode(data);
      return GestureDetector(
        onTap: () => _showFullscreenImage(context, bytes),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: _maxThumbHeight),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ),
      );
    }

    if (sourceType == 'url') {
      final url = source['url'] as String? ?? '';
      if (url.isEmpty) return const SizedBox.shrink();
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxThumbHeight),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Image.network(url, fit: BoxFit.contain),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _showFullscreenImage(BuildContext context, Uint8List bytes) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.9),
        barrierDismissible: true,
        pageBuilder: (context, _, _) {
          return GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.transparent,
              child: InteractiveViewer(
                maxScale: 8,
                child: Center(child: Image.memory(bytes, gaplessPlayback: true)),
              ),
            ),
          );
        },
      ),
    );
  }
}
