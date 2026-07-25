import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/sync_service.dart';
import 'package:happy_flutter/core/sync/invalidate_sync.dart';

import '../helpers/test_helpers.dart';

Session _makeSession({
  required String id,
  String presence = 'online',
  bool thinking = false,
  AgentState? agentState,
  Metadata? metadata,
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: true,
    activeAt: 1,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: presence,
    agentState: agentState,
    metadata: metadata,
  );
}

void main() {
  late Sync sync;

  setUp(() {
    sync = createTestSync();
    // Clear leaked state from previous tests (Sync is a singleton).
    sync.testNotifiedPermissionIds.clear();
    sync.testVisibleSessionId = null;
  });

  group('permission notification tracking', () {
    test('records new permission IDs in _notifiedPermissionIds', () {
      final session = _makeSession(
        id: 's1',
        agentState: AgentState(
          requests: {
            'perm-1': RequestInfo(tool: 'Bash', arguments: {
              'command': 'git status',
            }),
          },
        ),
      );

      sync.testCheckForNewPermissionRequests([session]);

      expect(sync.testNotifiedPermissionIds, contains('perm-1'));
    });

    test('does not duplicate notification for same permission ID', () {
      final session = _makeSession(
        id: 's1',
        agentState: AgentState(
          requests: {
            'perm-1': RequestInfo(tool: 'Bash'),
          },
        ),
      );

      sync.testCheckForNewPermissionRequests([session]);
      sync.testCheckForNewPermissionRequests([session]);

      // Still just one entry — no duplicates.
      expect(
        sync.testNotifiedPermissionIds.where((id) => id == 'perm-1').length,
        1,
      );
    });

    test('skips session the user is currently viewing', () {
      sync.testVisibleSessionId = 's1';

      final session = _makeSession(
        id: 's1',
        agentState: AgentState(
          requests: {
            'perm-1': RequestInfo(tool: 'Edit'),
          },
        ),
      );

      sync.testCheckForNewPermissionRequests([session]);

      expect(sync.testNotifiedPermissionIds, isEmpty);
    });

    test('notifies for non-visible sessions', () {
      sync.testVisibleSessionId = 's2';

      final session = _makeSession(
        id: 's1',
        agentState: AgentState(
          requests: {
            'perm-1': RequestInfo(tool: 'Bash'),
          },
        ),
      );

      sync.testCheckForNewPermissionRequests([session]);

      expect(sync.testNotifiedPermissionIds, contains('perm-1'));
    });

    test('skips sessions with no permission requests', () {
      final session = _makeSession(id: 's1');

      sync.testCheckForNewPermissionRequests([session]);

      expect(sync.testNotifiedPermissionIds, isEmpty);
    });

    test('skips sessions with empty requests map', () {
      final session = _makeSession(
        id: 's1',
        agentState: AgentState(requests: {}),
      );

      sync.testCheckForNewPermissionRequests([session]);

      expect(sync.testNotifiedPermissionIds, isEmpty);
    });

    test('handles multiple sessions with permissions', () {
      final sessions = [
        _makeSession(
          id: 's1',
          agentState: AgentState(
            requests: {
              'perm-1': RequestInfo(tool: 'Bash'),
            },
          ),
        ),
        _makeSession(
          id: 's2',
          agentState: AgentState(
            requests: {
              'perm-2': RequestInfo(tool: 'Edit'),
              'perm-3': RequestInfo(tool: 'Write'),
            },
          ),
        ),
      ];

      sync.testCheckForNewPermissionRequests(sessions);

      expect(sync.testNotifiedPermissionIds, {'perm-1', 'perm-2', 'perm-3'});
    });

    test('handles null agentState gracefully', () {
      final session = _makeSession(id: 's1', agentState: null);

      sync.testCheckForNewPermissionRequests([session]);

      expect(sync.testNotifiedPermissionIds, isEmpty);
    });

    test('handles null requests in agentState', () {
      final session = _makeSession(
        id: 's1',
        agentState: AgentState(),
      );

      sync.testCheckForNewPermissionRequests([session]);

      expect(sync.testNotifiedPermissionIds, isEmpty);
    });
  });
}
