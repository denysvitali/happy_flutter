import '../models/session.dart';
import 'session_utils.dart';
import 'vibing_messages.dart';

/// Session state enum representing the current state of a session.
enum SessionState {
  /// Session is not connected to the server.
  disconnected,

  /// Session is connected and agent is actively thinking/processing.
  thinking,

  /// Session is connected and waiting for user input.
  waiting,

  /// Session is connected but requires user permission to proceed.
  permissionRequired,
}

/// Status information for session display.
class SessionStatus {
  /// The current state of the session.
  final SessionState state;

  /// Whether the session is connected.
  final bool isConnected;

  /// The status text to display.
  final String statusText;

  /// Whether status should be shown.
  final bool shouldShowStatus;

  /// The status text color.
  final int statusColor;

  /// The status dot color.
  final int statusDotColor;

  /// Whether the status indicator should pulse/animate.
  final bool isPulsing;

  const SessionStatus({
    required this.state,
    required this.isConnected,
    required this.statusText,
    required this.shouldShowStatus,
    required this.statusColor,
    required this.statusDotColor,
    this.isPulsing = false,
  });
}

/// Gets the current status of a session based on presence and thinking status.
SessionStatus getSessionStatus(Session session) {
  final isOnline = session.presence == 'online';
  final hasPermissions =
      session.agentState?.requests != null && session.agentState!.requests!.isNotEmpty;

  if (!isOnline) {
    return SessionStatus(
      state: SessionState.disconnected,
      isConnected: false,
      statusText: 'Last seen ${formatLastSeen(session.activeAt)}',
      shouldShowStatus: true,
      statusColor: 0xFF999999,
      statusDotColor: 0xFF999999,
    );
  }

  // Check if permission is required
  if (hasPermissions) {
    return SessionStatus(
      state: SessionState.permissionRequired,
      isConnected: true,
      statusText: 'Permission required',
      shouldShowStatus: true,
      statusColor: 0xFFFF9500,
      statusDotColor: 0xFFFF9500,
      isPulsing: true,
    );
  }

  if (session.thinking) {
    final vibingMessage = getRandomVibingMessage();
    return SessionStatus(
      state: SessionState.thinking,
      isConnected: true,
      statusText: '${vibingMessage.toLowerCase()}...',
      shouldShowStatus: true,
      statusColor: 0xFF007AFF,
      statusDotColor: 0xFF007AFF,
      isPulsing: true,
    );
  }

  return SessionStatus(
    state: SessionState.waiting,
    isConnected: true,
    statusText: 'Online',
    shouldShowStatus: false,
    statusColor: 0xFF34C759,
    statusDotColor: 0xFF34C759,
  );
}
