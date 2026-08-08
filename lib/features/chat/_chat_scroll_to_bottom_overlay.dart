part of 'chat_screen.dart';

/// Overlay pill that scrolls the message list back to the bottom.
///
/// Listens to [autoScrollNotifier] directly so scroll events do NOT
/// trigger a full `_ChatScreenState` rebuild — the pill is a leaf
/// widget that re-renders only when the notifier value changes.
///
/// Extracted from the inline 40-line widget tree that previously lived
/// inside `_ChatScreenState._buildMasterPane`. The widget is pure:
/// no state mutation, no StreamSubscription access, no async. The
/// parent owns [autoScrollNotifier] and passes [isLoading] + [onTap]
/// as parameters.
///
/// Visibility logic:
/// - Pill is hidden when [autoScrollNotifier] value is `true`
///   (user is already at the bottom) or when [isLoading] is `true`
///   (don't fight the in-flight pagination).
/// - When visible, it fades and scales in over [AppDuration.normal].
class _ChatScrollToBottomOverlay extends StatelessWidget {
  const _ChatScrollToBottomOverlay({
    required this.autoScrollNotifier,
    required this.isLoading,
    required this.unreadCount,
    required this.onTap,
  });

  /// Whether the message list is at the bottom. The overlay hides
  /// itself when this is `true`.
  final ValueListenable<bool> autoScrollNotifier;

  /// When `true`, the overlay hides (in-flight pagination). Passed
  /// in as a plain `bool` because the parent already holds the
  /// loading flag; the overlay does not need its own notifier.
  final bool isLoading;

  /// Number of unread messages to show on the pill badge.
  final int unreadCount;

  /// Called when the user taps the pill. The parent is expected to
  /// (a) bump [autoScrollNotifier] back to `true` and (b) animate
  /// the scroll controller to the bottom.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<bool>(
        valueListenable: autoScrollNotifier,
        builder: (context, autoScroll, _) {
          final hidden = autoScroll || isLoading;
          return ExcludeSemantics(
            excluding: hidden,
            child: IgnorePointer(
              ignoring: hidden,
              child: AnimatedOpacity(
                opacity: hidden ? 0.0 : 1.0,
                duration: AppDuration.normal,
                curve: AppCurve.standard,
                child: AnimatedScale(
                  scale: hidden ? 0.8 : 1.0,
                  duration: AppDuration.normal,
                  curve: AppCurve.standard,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: ScrollToBottomPill(
                        onTap: onTap,
                        unreadCount: unreadCount,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
