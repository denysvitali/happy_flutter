import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/components/pressable_card.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_color_scheme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../markdown/markdown.dart';
import 'message_focus_view.dart';
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
/// Aurora Glass treatment: a translucent [AppColorScheme.bubbleUser] wash
/// over the pane surface, framed by a hairline [AppColorScheme.glassBorder]
/// and wrapped in a thin accent-gradient rim (the signature "edge glow").
class UserBubble extends StatefulWidget {
  const UserBubble({
    required this.text,
    super.key,
    this.imageBlocks,
    this.onOptionPress,
    this.sendStatus,
    this.sendSlow = false,
    this.codexDeliveryMode,
    this.onRetry,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.messageData,
  });

  final String text;

  /// Anthropic image blocks attached to this message, if any.
  final List<Map<String, dynamic>>? imageBlocks;

  final void Function(String)? onOptionPress;

  /// `null` = confirmed (server-origin), `'sending'`, `'sent'`,
  /// `'failed'`.
  final String? sendStatus;

  /// True when this message blew the client-side send deadline but the
  /// outbox retry confirmed the server already had it. Reported as
  /// "Delivered · slow" rather than left looking degraded.
  final bool sendSlow;

  /// Explicit Codex routing intent preserved in the user message metadata.
  final String? codexDeliveryMode;
  final VoidCallback? onRetry;
  final bool isFirstInGroup;
  final bool isLastInGroup;

  /// Raw message record, used to populate the long-press focus card.
  final Map<String, dynamic>? messageData;

  static const _full = Radius.circular(AppRadius.xl);
  static const _small = Radius.circular(AppRadius.xsm);

  /// Width of the accent-gradient rim around the glass fill.
  static const double _glow = 1.25;

  @override
  State<UserBubble> createState() => _UserBubbleState();
}

class _UserBubbleState extends State<UserBubble> {
  /// Marks the in-place bubble row so the focus view can animate its copy
  /// from exactly where the finger is.
  final GlobalKey _anchorKey = GlobalKey();

  String _truncateForLabel(String text) {
    const maxLength = 100;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  void _openFocusView() {
    HapticFeedback.heavyImpact();
    unawaited(
      showMessageFocusView(
        context,
        anchorKey: _anchorKey,
        text: widget.text,
        messageData: widget.messageData,
        messageBuilder: (ctx) => _row(ctx, interactive: false),
      ),
    );
  }

  /// The full bubble row (alignment + padding included).
  ///
  /// `interactive: false` drops the press/long-press wrapper so the same
  /// subtree can be re-rendered as the focused copy.
  Widget _row(BuildContext context, {required bool interactive}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Grouped radii: right side pinches for consecutive messages.
    final radius = BorderRadius.only(
      topLeft: UserBubble._full,
      topRight: widget.isFirstInGroup ? UserBubble._full : UserBubble._small,
      bottomLeft: UserBubble._full,
      bottomRight: widget.isLastInGroup ? UserBubble._full : UserBubble._small,
    );

    Widget bubbleFor(BoxConstraints constraints) {
      final appColors = theme.extension<AppColorScheme>();
      final fill = _userBubbleFill(theme, cs);
      final onFill = _userBubbleText(theme, cs);
      final hairline =
          appColors?.glassBorder ?? cs.outlineVariant.withValues(
            alpha: AppOpacity.soft,
          );
      final highlight =
          appColors?.glassHighlight ?? Colors.white.withValues(
            alpha: AppOpacity.subtle,
          );

      return Semantics(
        label: 'User message: ${_truncateForLabel(widget.text)}',
        button: false,
        child: Container(
          // Cap to the incoming pane, not the window. Tablet master-detail
          // and desktop splits are far narrower than MediaQuery.size.width.
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth * 0.80,
          ),
          // Accent-gradient rim: a gradient-painted shell inset by its own
          // width so only the edge reads as a glowing border. No package,
          // no shader mask, one extra box.
          padding: const EdgeInsets.all(UserBubble._glow),
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient:
                appColors?.accentLinearGradient ??
                LinearGradient(
                  colors:
                      appColors?.accentGradient ??
                      <Color>[cs.primary, cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
            boxShadow: [
              BoxShadow(
                color:
                    (appColors?.accentGradient ?? <Color>[cs.primary])
                        .first
                        .withValues(alpha: AppOpacity.soft),
                blurRadius: AppSpacing.lg,
                offset: const Offset(0, AppSpacing.xxxs),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md + 2,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: _inset(radius),
              border: Border.all(color: hairline, width: AppBorder.hairline),
            ),
            // Top-edge glass highlight painted by the same render object —
            // fades out over the upper third so light appears to fall on
            // the panel.
            foregroundDecoration: BoxDecoration(
              borderRadius: _inset(radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [highlight, highlight.withValues(alpha: 0)],
                stops: const [0, 0.4],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.imageBlocks != null) ...[
                  for (final block in widget.imageBlocks!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _UserImageThumb(block: block, onBubble: onFill),
                    ),
                ],
                if (widget.text.isNotEmpty)
                  MarkdownView(
                    markdown: widget.text,
                    onOptionPress: widget.onOptionPress,
                    textColor: onFill,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bubble = bubbleFor(constraints);
        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.xxl,
              right: AppSpacing.sm,
              top: widget.isFirstInGroup ? AppSpacing.xs : 1,
              bottom: widget.isLastInGroup ? AppSpacing.xs : 1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (interactive)
                  PressableCard(
                    onLongPress: _openFocusView,
                    pressedScale: 0.97,
                    enableHaptics: false,
                    duration: const Duration(milliseconds: 100),
                    child: bubble,
                  )
                else
                  bubble,
                if (widget.codexDeliveryMode == 'next-turn')
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xxs,
                      right: 2,
                    ),
                    child: Semantics(
                      label: context.l10n.chatQueuedForNextTurn,
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_send_rounded,
                            size: 11,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            context.l10n.chatQueuedForNextTurn,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  fontSize: AppFontSize.xxs,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.sendStatus != null)
                  SendStatusIndicator(
                    status: widget.sendStatus!,
                    slow: widget.sendSlow,
                    onRetry: interactive ? widget.onRetry : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _anchorKey,
      child: _row(context, interactive: true),
    );
  }
}

/// Glass fill for the user bubble: [AppColorScheme.bubbleUser] at ~16%
/// alpha flattened onto the pane surface. Pre-blending (instead of a
/// translucent box) keeps every bubble one opaque decoration — cheaper to
/// raster in long transcripts — while rendering identically over the
/// conversation canvas nothing shows through anyway.
Color _userBubbleFill(ThemeData theme, ColorScheme cs) {
  final appColors = theme.extension<AppColorScheme>();
  final bubble = appColors?.bubbleUser ?? cs.primary;
  return Color.alphaBlend(
    bubble.withValues(alpha: AppOpacity.soft),
    cs.surfaceContainerLow,
  );
}

/// Foreground that keeps WCAG-AA contrast on [_userBubbleFill]. On the
/// deep-space Aurora canvas (dark) that is [AppColorScheme.bubbleUserText]
/// (white on the darkened tint, >7:1). The pale light-mode glass cannot
/// carry white text (~1.2:1), so it inverts to the accent ink itself
/// ([AppColorScheme.bubbleUser], >5:1 on its own 16% wash) — the classic
/// light-theme iMessage inversion, still token-only.
Color _userBubbleText(ThemeData theme, ColorScheme cs) {
  final appColors = theme.extension<AppColorScheme>();
  if (theme.brightness == Brightness.dark) {
    return appColors?.bubbleUserText ?? cs.onPrimary;
  }
  return appColors?.bubbleUser ?? cs.primary;
}

/// Shrinks every corner of [radius] by the gradient-rim width so the glass
/// fill sits uniformly inside the shell instead of pooling at corners.
BorderRadius _inset(BorderRadius radius) {
  Radius shrink(Radius r) {
    final x = r.x - UserBubble._glow;
    return Radius.circular(x <= 0 ? 0 : x);
  }

  return BorderRadius.only(
    topLeft: shrink(radius.topLeft),
    topRight: shrink(radius.topRight),
    bottomLeft: shrink(radius.bottomLeft),
    bottomRight: shrink(radius.bottomRight),
  );
}

/// Inline thumbnail for an attached image inside a [UserBubble].
///
/// Base64 blocks render from memory; URL blocks (legacy markdown-image
/// sends) render from the network. Blocks whose base64 data was stripped
/// by the offline cache show a placeholder. Tapping opens a fullscreen
/// viewer with pinch zoom (same pattern as the session file viewer).
/// Thumbnail decode/render height bound shared by the bubble and its
/// inline image widget.
const double _kMaxThumbHeight = 220;

class _UserImageThumb extends StatelessWidget {
  const _UserImageThumb({required this.block, required this.onBubble});

  final Map<String, dynamic> block;

  /// Bubble foreground — placeholder icon/text must match the copy.
  final Color onBubble;

  static const double _maxThumbHeight = _kMaxThumbHeight;

  @override
  Widget build(BuildContext context) {
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
            color: onBubble.withValues(alpha: AppOpacity.faint),
            borderRadius: borderRadius,
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.image_not_supported_outlined,
                  size: AppIconSize.md,
                  color: onBubble.withValues(alpha: AppOpacity.high),
                ),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    l10n.chatImageNotCached,
                    style: TextStyle(
                      fontSize: AppFontSize.xs,
                      color: onBubble.withValues(alpha: AppOpacity.high),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return _CachedBase64Image(data: data, borderRadius: borderRadius);
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
}

/// Inline base64 image with a once-per-payload decode.
///
/// Decoding used to run inside `build`, so every parent rebuild (each
/// message tick while a session streams) re-ran `base64Decode` on a
/// potentially multi-MB payload and minted a fresh [MemoryImage] whose new
/// bytes identity missed the global ImageCache — a full-resolution
/// re-decode per tick of pure garbage, exactly the GC-stall freeze
/// signature (progressive-lag audit 2026-08-24). The decode now happens
/// once per distinct source string and the same [Uint8List] instance backs
/// every rebuild, so the provider stays `==` and the decoded image is
/// reused from the cache.
class _CachedBase64Image extends StatefulWidget {
  const _CachedBase64Image({required this.data, required this.borderRadius});

  final String data;
  final BorderRadius borderRadius;

  @override
  State<_CachedBase64Image> createState() => _CachedBase64ImageState();
}

class _CachedBase64ImageState extends State<_CachedBase64Image> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(_CachedBase64Image oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) _decode();
  }

  void _decode() {
    try {
      _bytes = base64Decode(widget.data);
    } on FormatException {
      // Malformed payload: render the not-cached placeholder instead of
      // crashing this bubble (the previous inline decode would have).
      _bytes = null;
    }
  }

  void _showFullscreen(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return;
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
                child: Center(
                  child: Image.memory(bytes, gaplessPlayback: true),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) {
      return Container(
        height: 72,
        width: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(
            alpha: AppOpacity.faint,
          ),
          borderRadius: widget.borderRadius,
        ),
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      );
    }
    return GestureDetector(
      onTap: () => _showFullscreen(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _kMaxThumbHeight),
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true),
        ),
      ),
    );
  }
}
