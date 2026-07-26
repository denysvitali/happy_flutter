import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clipboard_utils.dart';
import '../../../core/wire/wire_parsers.dart';
import 'message_detail_sheet.dart';

// ---------------------------------------------------------------------------
// Focused message view (long-press on a chat bubble)
// ---------------------------------------------------------------------------
//
// Long-pressing a message blurs the whole conversation behind a scrim and
// keeps a pixel-identical copy of that one message sharp, floating over the
// blur, with its details rendered as a card underneath.
//
// The copy is built by the caller (`messageBuilder`) from the very same
// subtree it renders in-place, and `anchorKey` marks that in-place subtree.
// Both are laid out at the same width, so the entrance animation is a pure
// vertical translation from where the finger is to the focused position.

/// Blur sigma applied to the conversation behind the focused message.
const double _kFocusBlurSigma = 20;

/// Scrim alpha at rest, over the blur.
const double _kFocusScrimAlpha = 0.30;

/// Built once: an ImageFilter rebuilt per frame makes the engine resample
/// the backdrop mid-animation, which showed up as a black band.
final ui.ImageFilter _blurFilter = ui.ImageFilter.blur(
  sigmaX: _kFocusBlurSigma,
  sigmaY: _kFocusBlurSigma,
  tileMode: TileMode.clamp,
);

/// Gap between the focused message and its details card.
const double _kFocusGap = AppSpacing.lg;

/// Max width of the details card (keeps it readable on tablets).
const double _kCardMaxWidth = 520;

/// A follow-up chosen inside the focus view. It is applied by the caller
/// *after* the overlay pops, so the copy snackbar and the raw-markdown
/// sheet attach to the chat route rather than to a route being torn down.
enum _FocusFollowUp { copy, selectText }

/// Opens the focused view for one chat message.
///
/// [messageBuilder] must build the same visual subtree that is rendered
/// in-place (alignment and padding included, gestures excluded) and must not
/// contain global keys. [anchorKey] is the key of the in-place subtree; it is
/// used only to animate the copy from its on-screen position.
Future<void> showMessageFocusView(
  BuildContext context, {
  required WidgetBuilder messageBuilder,
  required String text,
  GlobalKey? anchorKey,
  Map<String, dynamic>? messageData,
}) async {
  final anchorRect = _globalRectOf(anchorKey);
  final followUp = await Navigator.of(context, rootNavigator: true)
      .push<_FocusFollowUp>(
        PageRouteBuilder<_FocusFollowUp>(
          opaque: false,
          barrierColor: Colors.transparent,
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (ctx, animation, _) => MessageFocusOverlay(
            animation: animation,
            anchorRect: anchorRect,
            messageBuilder: messageBuilder,
            text: text,
            messageData: messageData,
          ),
        ),
      );

  if (followUp == null || !context.mounted) return;

  switch (followUp) {
    case _FocusFollowUp.copy:
      await setClipboardTextSafely(text);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.commonCopiedToClipboard),
          duration: const Duration(seconds: 1),
        ),
      );
    case _FocusFollowUp.selectText:
      showRawMarkdownSheet(context, text);
  }
}

/// Global bounds of the subtree [key] is attached to, or null when it is
/// unmounted or not laid out yet.
Rect? _globalRectOf(GlobalKey? key) {
  final ctx = key?.currentContext;
  if (ctx == null) return null;
  final box = ctx.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// The blur + focused-copy + details-card layer. Public for widget tests.
@visibleForTesting
class MessageFocusOverlay extends StatefulWidget {
  const MessageFocusOverlay({
    required this.animation,
    required this.messageBuilder,
    required this.text,
    this.anchorRect,
    this.messageData,
    super.key,
  });

  final Animation<double> animation;
  final WidgetBuilder messageBuilder;
  final String text;
  final Rect? anchorRect;
  final Map<String, dynamic>? messageData;

  @override
  State<MessageFocusOverlay> createState() => _MessageFocusOverlayState();
}

class _MessageFocusOverlayState extends State<MessageFocusOverlay> {
  /// Marks the focused copy so its resting rect can be measured.
  final GlobalKey _copyKey = GlobalKey();

  /// Translation applied to the copy at animation value 0 — i.e. the vector
  /// from its focused position back to the bubble the finger is on.
  Offset _entryOffset = Offset.zero;

  /// The copy is hidden for exactly one frame while it is measured, so it
  /// never flashes at its focused position before animating in.
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final target = _globalRectOf(_copyKey);
    final anchor = widget.anchorRect;
    setState(() {
      _measured = true;
      _entryOffset = (target == null || anchor == null)
          ? Offset.zero
          : anchor.topLeft - target.topLeft;
    });
  }

  void _dismiss([_FocusFollowUp? followUp]) {
    if (!mounted) return;
    Navigator.of(context).maybePop(followUp);
  }

  double get _progress =>
      Curves.easeOutCubic.transform(widget.animation.value.clamp(0.0, 1.0));

  /// Tint painted over the blur. A light theme frosts toward its own
  /// surface, a dark theme deepens toward the scrim, so the conversation
  /// stays faintly readable instead of going flat black.
  Color _scrimBase(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.scrim
        : theme.colorScheme.surface;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Focused message',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        child: Stack(
          children: [
            // Frosted conversation behind: the route is non-opaque, so the
            // chat below is still painted and can be blurred in place.
            //
            // The filter itself is a single stable object inside an explicit
            // ClipRect: rebuilding an ImageFilter per frame (ramping sigma
            // from 0) made the engine sample outside the backdrop and left a
            // hard-edged black band over part of the screen. Only the tint
            // animates now, and TileMode.clamp keeps edge samples opaque.
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: _blurFilter,
                  child: AnimatedBuilder(
                    animation: widget.animation,
                    builder: (context, _) => ColoredBox(
                      color: _scrimBase(context).withValues(
                        alpha: _kFocusScrimAlpha * _progress,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: SafeArea(
                left: false,
                right: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: _focusedCopy()),
                      const SizedBox(height: _kFocusGap),
                      _card(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The sharp copy of the message, sliding up from the bubble the user
  /// pressed. Long messages stay scrollable inside the focus view.
  Widget _focusedCopy() {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final t = _progress;
        return Opacity(
          opacity: _measured ? 1 : 0,
          child: Transform.translate(
            offset: Offset.lerp(_entryOffset, Offset.zero, t)!,
            child: child,
          ),
        );
      },
      child: SingleChildScrollView(
        child: Padding(
          // Reproduce the horizontal band the bubble occupies in the chat
          // list, so a bubble inside a narrow pane (tablet master/detail)
          // keeps its exact line wrapping in the focus view.
          padding: _anchorBand(context),
          child: KeyedSubtree(
            key: _copyKey,
            // The copy is decoration only: taps fall through to the barrier
            // so the whole screen dismisses, and drags still reach the
            // scroll view above it.
            child: IgnorePointer(child: widget.messageBuilder(context)),
          ),
        ),
      ),
    );
  }

  EdgeInsets _anchorBand(BuildContext context) {
    final anchor = widget.anchorRect;
    if (anchor == null) return EdgeInsets.zero;
    final width = MediaQuery.sizeOf(context).width;
    final left = anchor.left.clamp(0.0, width);
    final right = (width - anchor.right).clamp(0.0, width);
    if (left + right >= width) return EdgeInsets.zero;
    return EdgeInsets.only(left: left, right: right);
  }

  Widget _card() {
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) {
        final t = _progress;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * AppSpacing.xxl),
            child: child,
          ),
        );
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kCardMaxWidth),
          child: MessageFocusCard(
            text: widget.text,
            messageData: widget.messageData,
            onCopy: () => _dismiss(_FocusFollowUp.copy),
            onSelectText: () => _dismiss(_FocusFollowUp.selectText),
          ),
        ),
      ),
    );
  }
}

/// Details + actions card shown under a focused message.
///
/// Deliberately low-chrome: the message above it is the subject, so the
/// card is one line of meta chips over a row of actions — no title bar and
/// no close button (tapping anywhere outside dismisses).
@visibleForTesting
class MessageFocusCard extends StatelessWidget {
  const MessageFocusCard({
    required this.text,
    required this.onCopy,
    required this.onSelectText,
    this.messageData,
    super.key,
  });

  final String text;
  final Map<String, dynamic>? messageData;
  final VoidCallback onCopy;
  final VoidCallback onSelectText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = context.l10n;
    final data = messageData;

    // Message meta lives either directly on the message or inside the
    // decrypted `raw` record — same lookup the detail sheet does.
    final raw = WireParsers.asMap(data?['raw']);
    final meta =
        WireParsers.asMap(data?['meta']) ?? WireParsers.asMap(raw?['meta']);
    final model = data?['model'] as String? ?? meta?['model'] as String?;
    final permissionMode = meta?['permissionMode'] as String?;
    final createdAt = data?['createdAt'] as int?;
    final sendStatus = data?['sendStatus'] as String?;
    final messageId = data?['id']?.toString();

    final chips = <Widget>[
      if (model != null)
        _MetaChip(icon: Icons.auto_awesome_outlined, label: model),
      if (permissionMode != null)
        _MetaChip(icon: Icons.shield_outlined, label: permissionMode),
      if (sendStatus != null)
        _MetaChip(icon: Icons.send_outlined, label: sendStatus),
      if (createdAt != null)
        _MetaChip(
          icon: Icons.access_time_outlined,
          label: formatMessageTimestamp(createdAt, DateTime.now()),
        ),
    ];

    // A Material surface (not a plain Container) so the action row's ink
    // responses have the ancestor they require, and so the card gets its
    // elevation shadow over the blurred conversation.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Material(
        color: cs.surfaceContainerHigh.withValues(alpha: 0.96),
        elevation: 6,
        shadowColor: cs.shadow.withValues(alpha: AppOpacity.medium),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: AppOpacity.soft),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: chips.isEmpty
                  ? Text(
                      l10n.messageDetailNoDetails,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  : Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: chips,
                    ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: cs.outlineVariant.withValues(alpha: AppOpacity.soft),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _FocusAction(
                      icon: Icons.copy_rounded,
                      label: l10n.commonCopy,
                      onPressed: onCopy,
                    ),
                  ),
                  Expanded(
                    child: _FocusAction(
                      icon: Icons.text_fields_rounded,
                      label: l10n.messageFocusSelectText,
                      onPressed: onSelectText,
                    ),
                  ),
                  if (!kIsWeb && text.trim().isNotEmpty && messageId != null)
                    Expanded(
                      child: _SpeakAction(
                        messageId: messageId,
                        messageText: text,
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

/// Small pill showing one piece of message metadata.
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs + 1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: cs.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xxs + 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon-over-label action button used in the focus card's action row.
class _FocusAction extends StatelessWidget {
  const _FocusAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = highlighted ? cs.primary : cs.onSurface;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppTouchTarget.min,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
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

/// Speak / stop toggle that mirrors [TtsService] playback state, so the
/// focus view stays open while the message is being read out.
class _SpeakAction extends ConsumerWidget {
  const _SpeakAction({required this.messageId, required this.messageText});

  final String messageId;
  final String messageText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ValueListenableBuilder<String?>(
      valueListenable: TtsService().currentToken,
      builder: (context, currentToken, _) {
        final isPlaying = currentToken == messageId;
        return _FocusAction(
          icon: isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
          label: isPlaying
              ? l10n.messageFocusStopSpeaking
              : l10n.messageFocusSpeak,
          highlighted: isPlaying,
          onPressed: () {
            if (isPlaying) {
              TtsService().stop();
              return;
            }
            final settings = ref.read(settingsNotifierProvider);
            TtsService().speak(
              messageText,
              token: messageId,
              useOffline: settings.ttsUseOffline,
              offlineVoiceId: settings.ttsVoiceId,
            );
          },
        );
      },
    );
  }
}
