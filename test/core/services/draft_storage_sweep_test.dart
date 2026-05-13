// Tests for DraftStorage.computeStaleSessions — the pure algorithm
// underpinning sweepProfileReferences().
//
// Production GlitchTip surfaced ~9 warning events per day where a
// ChatScreen looked up a profile that no longer existed. The fix
// removes the stale per-session profile mapping when a profile is
// deleted from settings. This test pins the algorithm.

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/draft_storage.dart';

void main() {
  group('DraftStorage.computeStaleSessions', () {
    test('returns empty list when there are no entries', () {
      expect(
        DraftStorage.computeStaleSessions(const {}, 'profile_x'),
        isEmpty,
      );
    });

    test('returns empty list when profileId is empty', () {
      expect(
        DraftStorage.computeStaleSessions(
          const {'s1': 'profile_x', 's2': 'profile_y'},
          '',
        ),
        isEmpty,
      );
    });

    test(
      'returns only session ids whose stored profile matches '
      'the deleted profile id',
      () {
        final entries = <String, String>{
          'session-a': 'profile_kept',
          'session-b': 'profile_deleted',
          'session-c': 'profile_deleted',
          'session-d': 'profile_other',
        };

        final stale = DraftStorage.computeStaleSessions(
          entries,
          'profile_deleted',
        );

        expect(stale, containsAll(<String>['session-b', 'session-c']));
        expect(stale, hasLength(2));
        expect(stale, isNot(contains('session-a')));
        expect(stale, isNot(contains('session-d')));
      },
    );

    test('returns empty list when no entry matches', () {
      final entries = <String, String>{
        'session-a': 'profile_a',
        'session-b': 'profile_b',
      };

      expect(
        DraftStorage.computeStaleSessions(entries, 'profile_ghost'),
        isEmpty,
      );
    });

    test('does not throw on a map with one entry matching itself', () {
      final entries = <String, String>{'only-session': 'only-profile'};

      final stale = DraftStorage.computeStaleSessions(
        entries,
        'only-profile',
      );

      expect(stale, equals(<String>['only-session']));
    });
  });
}
