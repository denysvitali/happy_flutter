import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/main_isolate_stall_tracker.dart';
import 'package:happy_flutter/core/services/session_catalog_decode_memo.dart';

void main() {
  group('SessionCatalogDecodeMemo', () {
    final decryptor = Object();

    test('hits only the same decryptor, version and ciphertext', () {
      final memo = SessionCatalogDecodeMemo();
      final metadata = Metadata(host: 'h');
      memo.putMetadata('s', catalogBlobKey(decryptor, 3, 'abc'), (
        metadata: metadata,
        todos: null,
      ));

      expect(
        memo.metadata('s', catalogBlobKey(decryptor, 3, 'abc'))?.metadata,
        same(metadata),
      );
      expect(memo.metadata('s', catalogBlobKey(decryptor, 4, 'abc')), isNull);
      expect(memo.metadata('s', catalogBlobKey(decryptor, 3, 'abd')), isNull);
      expect(memo.metadata('s', catalogBlobKey(Object(), 3, 'abc')), isNull);
      expect(memo.metadata('t', catalogBlobKey(decryptor, 3, 'abc')), isNull);
    });

    test('an agent-state hit can carry a null value', () {
      final memo = SessionCatalogDecodeMemo();
      final key = catalogBlobKey(decryptor, 1, null);
      expect(memo.agentState('s', key), isNull);
      memo.putAgentState('s', key, null);
      final hit = memo.agentState('s', key);
      expect(hit, isNotNull);
      expect(hit!.value, isNull);
    });

    test('retainOnly prunes sessions the catalog no longer returns', () {
      final memo = SessionCatalogDecodeMemo();
      for (final id in ['a', 'b']) {
        final key = catalogBlobKey(decryptor, 1, id);
        memo
          ..putMetadata(id, key, (metadata: null, todos: null))
          ..putAgentState(id, key, null);
      }
      memo.retainOnly({'a'});
      expect(memo.metadataCount, 1);
      expect(memo.agentStateCount, 1);
      memo.clear();
      expect(memo.metadataCount, 0);
    });
  });

  group('runInYieldingBatches', () {
    tearDown(MainIsolateStallTracker.instance.reset);

    test('keeps order and yields to timers between slices', () async {
      var timerFired = false;
      final seen = <bool>[];
      final results = await runInYieldingBatches<int, int>(
        List<int>.generate(40, (i) => i),
        (i) async {
          if (i == 0) Timer(Duration.zero, () => timerFired = true);
          seen.add(timerFired);
          return i * 2;
        },
        name: 'test.slice',
        isStale: () => false,
        batchSize: 16,
      );

      expect(results, List<int>.generate(40, (i) => i * 2));
      // The first slice runs before the timer; later slices after it.
      expect(seen.sublist(0, 16).every((fired) => !fired), isTrue);
      expect(seen.sublist(16).every((fired) => fired), isTrue);
    });

    test('stops starting slices once stale', () async {
      var calls = 0;
      var stale = false;
      final results = await runInYieldingBatches<int, int>(
        List<int>.generate(40, (i) => i),
        (i) async {
          calls++;
          stale = true;
          return i;
        },
        name: 'test.slice',
        isStale: () => stale,
        batchSize: 16,
      );

      expect(results, isNull);
      expect(calls, 16);
    });

    test('records a long slice for frozen-frame attribution', () async {
      var now = 0;
      MainIsolateStallTracker.instance.clock = () => now;
      await runInYieldingBatches<int, int>(
        [1],
        (i) async {
          now += 20000;
          return i;
        },
        name: 'sessions_fetch.decrypt',
        isStale: () => false,
      );

      expect(
        MainIsolateStallTracker.instance.blockerBetween(0, 20000),
        'sessions_fetch.decrypt',
      );
    });
  });
}
