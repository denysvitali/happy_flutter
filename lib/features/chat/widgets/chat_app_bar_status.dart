// Status-line data and builders for [ChatAppBar].
//
// Split out of `chat_app_bar.dart` to keep that file under the repo's
// 800-line cap: the app bar keeps the widgets, this file keeps the chip
// model, the chip builder, and the store fallback used while the chat
// screen is still loading its session.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/session_utils.dart';
import 'model_mode.dart';

class ChatAppBarStatusChip {
  const ChatAppBarStatusChip({
    required this.text,
    required this.color,
    this.icon = Icons.circle,
    this.showDot = false,
    this.pulse = false,
  });

  final String text;
  final Color color;
  final IconData icon;
  final bool showDot;
  final bool pulse;
}

/// Session to render in the app bar: the one the chat screen has loaded,
/// or — while that load is still in flight — the one already known to the
/// sessions store.
///
/// Without this fallback the wide (master-detail) layout showed the generic
/// "Chat" title for the whole load, even though the list pane next to it was
/// already displaying the session's name.
Session? effectiveChatAppBarSession(
  WidgetRef ref, {
  required Session? loaded,
  required String sessionId,
}) {
  if (loaded != null) return loaded;
  return ref.watch(
    sessionsNotifierProvider.select((sessions) => sessions[sessionId]),
  );
}

/// Status line used while the chat screen is still loading: the session's
/// path plus its online/offline presence, mirroring the list pane.
List<ChatAppBarStatusChip> chatAppBarFallbackChips(
  BuildContext context,
  Session resolved,
) {
  final cs = Theme.of(context).colorScheme;
  final online = resolved.isPresenceOnline;
  return [
    ChatAppBarStatusChip(
      text: getSessionSubtitle(resolved),
      color: cs.onSurfaceVariant,
      icon: Icons.folder_outlined,
    ),
    ChatAppBarStatusChip(
      text: online ? context.l10n.statusOnline : context.l10n.statusOffline,
      color: online ? cs.primary : cs.onSurfaceVariant,
      showDot: true,
    ),
  ];
}

/// Formats a "last seen N ago" label for the offline chip, picking
/// the closest l10n bucket (just-now / minutes / hours / days).
///
/// Pure function — takes a BuildContext for l10n and an epoch-ms
/// activeAt timestamp. Extracted from _ChatScreenState so the chip
/// logic can live next to the [ChatAppBar] data classes.
String formatLastSeenLabel(BuildContext context, int activeAt) {
  final l10n = context.l10n;
  final lastSeen = DateTime.fromMillisecondsSinceEpoch(activeAt);
  final diff = DateTime.now().difference(lastSeen);
  if (diff.inMinutes < 1) return l10n.chatLastSeenJustNow;
  if (diff.inMinutes < 60) {
    return l10n.chatLastSeenMinutes(diff.inMinutes);
  }
  if (diff.inHours < 24) {
    return l10n.chatLastSeenHours(diff.inHours);
  }
  return l10n.chatLastSeenDays(diff.inDays);
}

/// Inputs the [ChatAppBar] needs from the chat screen's reactive
/// state to render the status chips. The chat screen watches each
/// of these and passes the latest values in.
///
/// Splitting the input as a typed record (vs. a long parameter
/// list) keeps the call site readable and makes the contract
/// explicit — adding a new chip only touches this record, not the
/// helper signature.
class ChatStatusChipsInputs {
  const ChatStatusChipsInputs({
    required this.session,
    required this.isReady,
    required this.hasRequests,
    required this.sendIssue,
    required this.latestUserMessage,
    required this.lastVisibleNonSidechainCreatedAt,
    required this.debugMaxSeq,
    required this.modelMode,
    this.lastMessageStreamActivityAt = 0,
    this.isStopping = false,
    this.isReconnecting = false,
  });

  final Session session;
  final bool isReady;
  final bool hasRequests;

  /// A pre-resolved lifecycle-error issue, or `null` if the session
  /// has no lifecycle error. The chat screen builds the issue from
  /// session metadata before calling the helper.
  final SendIssue? sendIssue;

  /// The most recent user message map (or `null` if no messages
  /// sent). The helper reads `sendStatus` from this map.
  final Map<String, dynamic>? latestUserMessage;

  /// Timestamp (ms since epoch) of the last visible (non-sidechain)
  /// message. Used to detect when the agent is in a "working on
  /// sub-tasks" state.
  final int lastVisibleNonSidechainCreatedAt;

  /// Debug-only seq watermark. -1 hides the chip.
  final int debugMaxSeq;

  /// Local timestamp (ms since epoch) of the last time this session's
  /// message stream changed — including sidechain children merging into
  /// collapsed Task rows, which produce no new visible message. Lets the
  /// chips surface "Working on sub-tasks" even when the `thinking` flag
  /// has gone stale during a long turn. 0 means no change observed yet.
  final int lastMessageStreamActivityAt;

  /// An abort request is in flight. This state takes visual precedence over
  /// ordinary online/thinking state so repeated stop taps are discouraged.
  final bool isStopping;

  /// The shared socket is actively reconnecting.
  final bool isReconnecting;

  /// Current model selection. `ChatModelMode.defaultModel` hides
  /// the chip.
  final ChatModelMode modelMode;
}

/// Lightweight view of a session lifecycle error that the chat
/// screen can hand to the chip builder. The chat screen's own
/// `_SessionSendIssue` is library-private; the chip builder only
/// needs the two facts it renders.
class SendIssue {
  const SendIssue({
    required this.title,
    required this.message,
    required this.blocksSend,
  });
  final String title;
  final String message;
  final bool blocksSend;
}

/// Builds the list of [ChatAppBarStatusChip]s shown in the app bar.
///
/// Pure function: takes the chat screen's reactive state as
/// [inputs] and returns the chip list. No `ref.watch`, no
/// `Theme.of(context)` — callers pass in `colorScheme` and
/// `BuildContext` for l10n. The chat screen stays in control of
/// rebuild scope.
List<ChatAppBarStatusChip> buildChatStatusChips({
  required BuildContext context,
  required ColorScheme colorScheme,
  required ChatStatusChipsInputs inputs,
}) {
  final session = inputs.session;
  final l10n = context.l10n;
  final chips = <ChatAppBarStatusChip>[];
  final hasRequests = inputs.hasRequests;
  final sendIssue = inputs.sendIssue;
  final lifecycleState = session.effectiveLifecycleState;
  final lifecycleSince = session.metadata?.lifecycleStateSince;
  final metadata = session.metadata;
  final kubernetesStartup =
      metadata?.runtimeKind == 'kubernetes' ||
      (metadata?.repoUrl?.isNotEmpty ?? false);
  final lifecycleRecentWindowMs = kubernetesStartup ? 300000 : 120000;
  final lifecycleIsRecent =
      lifecycleSince != null &&
      DateTime.now().millisecondsSinceEpoch - lifecycleSince <
          lifecycleRecentWindowMs;
  final isConnecting =
      inputs.isReconnecting ||
      !inputs.isReady &&
          lifecycleIsRecent &&
          (lifecycleState == 'starting' || lifecycleState == 'running');

  if (inputs.isStopping) {
    chips.add(
      ChatAppBarStatusChip(
        text: l10n.chatStatusStopping,
        color: colorScheme.primary,
        icon: Icons.stop_circle_outlined,
      ),
    );
  } else if (sendIssue != null) {
    chips.add(
      ChatAppBarStatusChip(
        text: sendIssue.blocksSend
            ? l10n.chatStatusAgentFailed
            : l10n.chatStatusWillRestart,
        color: sendIssue.blocksSend ? AppColors.error : AppColors.warning,
        icon: sendIssue.blocksSend
            ? Icons.error_outline_rounded
            : Icons.restart_alt_rounded,
      ),
    );
  } else if (inputs.isReady) {
    chips.add(
      ChatAppBarStatusChip(
        text: l10n.chatOnline,
        color: AppColors.success,
        showDot: true,
        // Steady state: no pulse. A pulsing dot here runs a 60fps
        // repeating animation for as long as any ready chat is open, which
        // was the dominant foreground battery drain (see ROADMAP "Foreground
        // battery draw"). Pulse is reserved for transient states (thinking)
        // in SessionStatus.isPulsing.
        pulse: false,
      ),
    );
  } else if (isConnecting) {
    chips.add(
      ChatAppBarStatusChip(
        text: inputs.isReconnecting
            ? l10n.chatStatusReconnecting
            : l10n.chatStatusConnecting,
        color: colorScheme.primary,
        icon: Icons.sync_rounded,
      ),
    );
  } else {
    chips
      ..add(
        ChatAppBarStatusChip(
          text: l10n.statusOffline,
          color: colorScheme.outline,
          icon: Icons.cloud_off_rounded,
        ),
      )
      ..add(
        ChatAppBarStatusChip(
          text: formatLastSeenLabel(context, session.activeAt),
          color: colorScheme.onSurfaceVariant,
          icon: Icons.schedule_rounded,
        ),
      );
  }

  if (hasRequests) {
    chips.add(
      ChatAppBarStatusChip(
        text: l10n.chatStatusApprovalNeeded,
        color: AppColors.warning,
        icon: Icons.shield_outlined,
      ),
    );
  } else if (!inputs.isStopping) {
    // When the agent has been "thinking" for a while with no new
    // visible (non-sidechain) message, surface that the work is
    // likely happening inside sub-tasks. Without this signal the
    // chat looks paused — see the long-running session diagnosis
    // on c8400ba… where 2000+ server messages produced almost no
    // visible bubbles.
    const subTaskSwitchMs = 30000;
    final lastVisibleCreatedAt = inputs.lastVisibleNonSidechainCreatedAt;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final stale =
        lastVisibleCreatedAt > 0 &&
        nowMs - lastVisibleCreatedAt > subTaskSwitchMs;
    if (session.thinking) {
      chips.add(
        ChatAppBarStatusChip(
          text: stale
              ? l10n.chatStatusWorkingOnSubtasks
              : l10n.chatStatusThinking,
          color: colorScheme.primary,
          showDot: !stale,
          icon: Icons.account_tree_outlined,
        ),
      );
    } else {
      // The thinking flag is set once at turn start and can go stale
      // during a long turn, while sub-agent traffic keeps merging into
      // collapsed Task rows — no new visible message, chat looks dead
      // even though the session is hard at work (session c04ffa4d…).
      // Fall back to message-stream activity: fresh changes with a
      // stale visible tail means hidden sub-task work.
      const hiddenActivityWindowMs = 60000;
      final lastStreamActivity = inputs.lastMessageStreamActivityAt;
      final hiddenActivity =
          lastStreamActivity > 0 &&
          nowMs - lastStreamActivity <= hiddenActivityWindowMs &&
          stale;
      if (hiddenActivity) {
        chips.add(
          ChatAppBarStatusChip(
            text: l10n.chatStatusWorkingOnSubtasks,
            color: colorScheme.primary,
            icon: Icons.account_tree_outlined,
          ),
        );
      }
    }
  }

  // Debug-only seq watermark — proves the session is alive when
  // the visible chat looks idle. Highest seq we have decrypted
  // (incl. sidechain). The user requested this after observing
  // seq=2000+ with few visible messages.
  if (kDebugMode) {
    final maxSeq = inputs.debugMaxSeq;
    if (maxSeq >= 0) {
      chips.add(
        ChatAppBarStatusChip(
          text: 'seq=$maxSeq',
          color: colorScheme.outline,
          icon: Icons.bug_report_outlined,
        ),
      );
    }
  }

  final sendStatus = inputs.latestUserMessage?['sendStatus'] as String?;
  if (sendStatus != null) {
    switch (sendStatus) {
      case 'sending':
        chips.add(
          ChatAppBarStatusChip(
            text: l10n.chatSending,
            color: colorScheme.onSurfaceVariant,
            icon: Icons.arrow_upward_rounded,
          ),
        );
        break;
      case 'pending':
        chips.add(
          ChatAppBarStatusChip(
            text: l10n.chatStatusRetryQueued,
            color: AppColors.warning,
            icon: Icons.schedule_rounded,
          ),
        );
        break;
      case 'failed':
        chips.add(
          ChatAppBarStatusChip(
            text: l10n.chatStatusNotDelivered,
            color: AppColors.error,
            icon: Icons.error_outline_rounded,
          ),
        );
        break;
      case 'sent':
        // Only worth a chip when the send was slow: a send that blew the
        // client deadline but turned out to be persisted already used to
        // leave "Retry queued" as the last thing the user saw.
        if (inputs.latestUserMessage?['sendSlow'] == true) {
          chips.add(
            ChatAppBarStatusChip(
              text: l10n.chatStatusSentSlow,
              color: colorScheme.onSurfaceVariant,
              icon: Icons.schedule_rounded,
            ),
          );
        }
        break;
    }
  }

  if (inputs.modelMode != ChatModelMode.defaultModel) {
    chips.add(
      ChatAppBarStatusChip(
        text: inputs.modelMode.label,
        color: colorScheme.onSurfaceVariant,
        icon: Icons.tune_rounded,
      ),
    );
  }

  return chips;
}
