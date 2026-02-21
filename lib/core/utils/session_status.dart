import 'package:flutter/painting.dart';

import '../models/session.dart';
import '../theme/app_colors.dart';
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

  const SessionStatus({
    required this.state,
    required this.isConnected,
    required this.statusText,
    required this.shouldShowStatus,
    required this.statusColor,
    required this.statusDotColor,
    this.isPulsing = false,
  });
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
}

/// Gets the current status of a session based on presence and thinking status.
SessionStatus getSessionStatus(Session session) {
  final isOnline = session.presence == 'online';
  final hasPermissions =
      session.agentState?.requests != null &&
      session.agentState!.requests!.isNotEmpty;

  if (!isOnline) {
    return SessionStatus(
      state: SessionState.disconnected,
      isConnected: false,
      statusText: 'Last seen ${formatLastSeen(session.activeAt)}',
      shouldShowStatus: true,
      statusColor: const Color(0xFF999999).toARGB32(),
      statusDotColor: const Color(0xFF999999).toARGB32(),
    );
  }

  // Check if permission is required
  if (hasPermissions) {
    return SessionStatus(
      state: SessionState.permissionRequired,
      isConnected: true,
      statusText: 'Permission required',
      shouldShowStatus: true,
      statusColor: AppColors.warning.toARGB32(),
      statusDotColor: AppColors.warning.toARGB32(),
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
      statusColor: AppColors.iosBlue.toARGB32(),
      statusDotColor: AppColors.iosBlue.toARGB32(),
      isPulsing: true,
    );
  }

  return SessionStatus(
    state: SessionState.waiting,
    isConnected: true,
    statusText: 'Online',
    shouldShowStatus: false,
    statusColor: AppColors.success.toARGB32(),
    statusDotColor: AppColors.success.toARGB32(),
  );
}
