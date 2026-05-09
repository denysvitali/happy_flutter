/// Native chat list "islands" — stub only (item #6 of the
/// architecture overhaul). Do not implement.
///
/// Behind [kUseNativeChatList] (defaults to false), the chat screen
/// can substitute a [PlatformView]-backed list for the Flutter
/// [ListView]. The real implementation would live behind two
/// platform views:
///
///   * Android: `androidx.recyclerview.widget.RecyclerView` driven
///     by a `MessageListAdapter` that reads from a Flutter ↔ native
///     channel.
///   * iOS:     `UICollectionView` with a compositional layout and
///     `UIHostingConfiguration` for SwiftUI bubbles.
///
/// The Flutter side ships projection updates as already-rendered
/// frames (see lib/core/event_log/message_projection.dart) so the
/// native side never needs to know about Sync's internals.
///
/// What this scaffold delivers
/// ---------------------------
///   * The flag (kept off by default).
///   * A profiling hook ([logFrameTiming]) that the real native
///     impl would call from its scroll listener.
///   * A widget shell that returns the existing Flutter list when
///     the flag is off, and a placeholder otherwise so we can build
///     the platform-channel scaffolding incrementally.
library;

import 'package:flutter/widgets.dart';

bool _kUseNativeChatList = false;

bool get kUseNativeChatList => _kUseNativeChatList;

/// Test-only setter. Production code should only ever read the flag.
@visibleForTesting
set kUseNativeChatListForTest(bool value) {
  _kUseNativeChatList = value;
}

/// Profiling hook called from the platform side once per scroll-end
/// to record the average frame time. The Flutter side forwards to
/// `logger.info`/Sentry breadcrumbs in the real impl.
typedef FrameTimingSink = void Function({
  required String sessionId,
  required double avgFrameMs,
  required int frameCount,
});

FrameTimingSink? _sink;
FrameTimingSink? get frameTimingSink => _sink;
set frameTimingSink(FrameTimingSink? sink) => _sink = sink;

void logFrameTiming({
  required String sessionId,
  required double avgFrameMs,
  required int frameCount,
}) {
  _sink?.call(
    sessionId: sessionId,
    avgFrameMs: avgFrameMs,
    frameCount: frameCount,
  );
}

/// Holder widget. When the flag is off this is the identity wrapper.
/// When on, returns a placeholder so the rest of the chat screen
/// renders without crashing — the real native bridge is intentionally
/// not implemented here.
class NativeChatListIsland extends StatelessWidget {
  const NativeChatListIsland({
    required this.fallback,
    super.key,
  });

  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (!_kUseNativeChatList) return fallback;
    return const _NativeChatListPlaceholder();
  }
}

class _NativeChatListPlaceholder extends StatelessWidget {
  const _NativeChatListPlaceholder();

  @override
  Widget build(BuildContext context) {
    // Real impl would return AndroidView / UiKitView here, wired to
    // a MessageListAdapter receiving projection updates over a
    // MethodChannel.
    return const SizedBox.shrink();
  }
}
