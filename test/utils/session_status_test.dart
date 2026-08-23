import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/theme/app_colors.dart';
import 'package:happy_flutter/core/utils/session_status.dart';

Session _makeSession({
  String presence = 'online',
  bool thinking = false,
  int activeAt = 0,
  AgentState? agentState,
}) {
  return Session(
    id: 's1',
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: true,
    activeAt: activeAt,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: presence,
    agentState: agentState,
  );
}

void main() {
  group('SessionState enum', () {
    test('has expected values', () {
      expect(SessionState.values.length, 4);
      expect(SessionState.values, contains(SessionState.disconnected));
      expect(SessionState.values, contains(SessionState.thinking));
      expect(SessionState.values, contains(SessionState.waiting));
      expect(SessionState.values, contains(SessionState.permissionRequired));
    });
  });

  group('SessionStatus', () {
    test('stores all fields', () {
      const status = SessionStatus(
        state: SessionState.waiting,
        isConnected: true,
        statusText: 'Online',
        shouldShowStatus: false,
        statusColor: 0xFF000000,
        statusDotColor: 0xFF000000,
        isPulsing: false,
      );
      expect(status.state, SessionState.waiting);
      expect(status.isConnected, isTrue);
      expect(status.statusText, 'Online');
      expect(status.shouldShowStatus, isFalse);
      expect(status.isPulsing, isFalse);
    });

    test('isPulsing defaults to false', () {
      const status = SessionStatus(
        state: SessionState.waiting,
        isConnected: true,
        statusText: '',
        shouldShowStatus: false,
        statusColor: 0,
        statusDotColor: 0,
      );
      expect(status.isPulsing, isFalse);
    });
  });

  group('getSessionStatus', () {
    test('offline session is disconnected', () {
      final session = _makeSession(
        presence: 'offline',
        activeAt: DateTime.now().millisecondsSinceEpoch,
      );
      final status = getSessionStatus(session);
      expect(status.state, SessionState.disconnected);
      expect(status.isConnected, isFalse);
      expect(status.shouldShowStatus, isTrue);
      expect(status.statusText.startsWith('Last seen'), isTrue);
      expect(
        status.statusColor,
        const Color(0xFF999999).toARGB32(),
      );
    });

    test('online session with permissions requires permission', () {
      final session = _makeSession(
        agentState: AgentState(
          requests: {
            'req1': RequestInfo(tool: 'Bash', arguments: {}),
          },
        ),
      );
      final status = getSessionStatus(session);
      expect(status.state, SessionState.permissionRequired);
      expect(status.isConnected, isTrue);
      expect(status.statusText, 'Permission required');
      expect(status.shouldShowStatus, isTrue);
      // Steady state — pulse is reserved for transitional states (thinking).
      expect(status.isPulsing, isFalse);
      expect(
        status.statusColor,
        AppColors.warning.toARGB32(),
      );
    });

    test('thinking session shows thinking state', () {
      final session = _makeSession(thinking: true);
      final status = getSessionStatus(session);
      expect(status.state, SessionState.thinking);
      expect(status.isConnected, isTrue);
      expect(status.statusText, '');
      expect(status.shouldShowStatus, isFalse);
      expect(status.isPulsing, isTrue);
      expect(
        status.statusColor,
        AppColors.iosBlue.toARGB32(),
      );
    });

    test('online non-thinking session is waiting', () {
      final session = _makeSession(presence: 'online', thinking: false);
      final status = getSessionStatus(session);
      expect(status.state, SessionState.waiting);
      expect(status.isConnected, isTrue);
      expect(status.statusText, 'Online');
      expect(status.shouldShowStatus, isFalse);
      expect(status.isPulsing, isFalse);
      expect(
        status.statusColor,
        AppColors.success.toARGB32(),
      );
    });

    test('permission check takes priority over thinking', () {
      final session = _makeSession(
        thinking: true,
        agentState: AgentState(
          requests: {
            'req1': RequestInfo(tool: 'Read', arguments: {}),
          },
        ),
      );
      final status = getSessionStatus(session);
      expect(status.state, SessionState.permissionRequired);
    });

    test('empty requests map does not trigger permission', () {
      final session = _makeSession(
        agentState: AgentState(requests: {}),
      );
      final status = getSessionStatus(session);
      expect(status.state, SessionState.waiting);
    });

    test('null agentState does not trigger permission', () {
      final session = _makeSession(agentState: null);
      final status = getSessionStatus(session);
      expect(status.state, SessionState.waiting);
    });

    test('offline takes priority over thinking', () {
      final session = _makeSession(
        presence: 'offline',
        thinking: true,
        activeAt: DateTime.now().millisecondsSinceEpoch,
      );
      final status = getSessionStatus(session);
      expect(status.state, SessionState.disconnected);
    });

    test('status colors match state', () {
      final offline = getSessionStatus(
        _makeSession(
          presence: 'offline',
          activeAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      expect(offline.statusDotColor, offline.statusColor);

      final thinking = getSessionStatus(_makeSession(thinking: true));
      expect(thinking.statusDotColor, thinking.statusColor);

      final waiting = getSessionStatus(_makeSession());
      expect(waiting.statusDotColor, waiting.statusColor);
    });
  });
}
