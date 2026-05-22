import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/models/friend_request.dart';
import '../../../core/theme/app_tokens.dart';

/// A card displaying a single inbound friend request with sticky
/// side-by-side accept (check) and decline (x) icon buttons.
///
/// Both buttons trigger [HapticFeedback.lightImpact] on press.
/// The card disables both buttons while an action is in-flight
/// ([isPending] == true).
class FriendRequestCard extends StatelessWidget {
  const FriendRequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
    super.key,
    this.isPending = false,
  });

  final FriendRequest request;

  /// Called when the user taps the accept (check) button.
  final VoidCallback onAccept;

  /// Called when the user taps the decline (x) button.
  final VoidCallback onDecline;

  /// Whether an accept/decline call is currently in-flight for this request.
  /// When true, both buttons are disabled and a spinner replaces the icons.
  final bool isPending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smd,
        ),
        child: Row(
          children: [
            // ── Avatar ──────────────────────────────────────────────
            _Avatar(avatarUrl: request.fromAvatarUrl, size: 40),
            const SizedBox(width: AppSpacing.md),

            // ── Name + username ─────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    request.fromDisplayName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (request.fromUsername.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '@${request.fromUsername}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            // ── Action buttons (sticky, side-by-side) ───────────────
            if (isPending)
              SizedBox(
                width: AppTouchTarget.min * 2 + AppSpacing.xs,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: Icons.check_rounded,
                    tooltip: 'Accept',
                    color: cs.primary,
                    backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                    onTap: onAccept,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  _ActionButton(
                    icon: Icons.close_rounded,
                    tooltip: 'Decline',
                    color: cs.error,
                    backgroundColor: cs.errorContainer.withValues(alpha: 0.5),
                    onTap: onDecline,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─── _ActionButton ────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: AppDuration.fast,
          curve: AppCurve.standard,
          child: Container(
            width: AppTouchTarget.min,
            height: AppTouchTarget.min,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(
              widget.icon,
              size: AppSpacing.xl,
              color: widget.color,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── _Avatar ──────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size, this.avatarUrl});

  final double size;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(cs, size),
        ),
      );
    }
    return _placeholder(cs, size);
  }

  Widget _placeholder(ColorScheme cs, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_outline_rounded,
        size: size * 0.55,
        color: cs.onPrimaryContainer,
      ),
    );
  }
}
