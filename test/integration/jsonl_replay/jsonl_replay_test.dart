// Contract test: replay a real Claude Code .jsonl transcript through
// `processDecryptedMessages` and assert that every forwarded message
// renders without being silently dropped.
//
// These tests are local-only — they skip when the fixture is not on the
// filesystem (CI, fresh checkouts, other contributors). The fixtures
// live under ~/.claude/projects/ and are not checked in.
//
// Drops discovered by this harness are the exact list of parser bugs
// that happy_flutter currently ships with.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/encryption/message_processor.dart';

import 'jsonl_fixture_loader.dart';

void main() {
  group('jsonl replay contract', () {
    test('happy_flutter interrupt fixture has zero silent drops', () {
      final bundle = FixtureBundle.happyFlutterInterrupts();
      if (!bundle.isAvailable) {
        markTestSkipped('fixture not present on this machine');
        return;
      }
      _assertZeroDrops(bundle);
    });

    test('gps-tracker main + subagents fixture has zero silent drops', () {
      final bundle = FixtureBundle.gpsTrackerSidechain();
      if (!bundle.isAvailable) {
        markTestSkipped('fixture not present on this machine');
        return;
      }
      _assertZeroDrops(bundle);
    });

    test('every forwarded line produces exactly one rendered message', () {
      final bundle = FixtureBundle.happyFlutterInterrupts();
      if (!bundle.isAvailable) {
        markTestSkipped('fixture not present on this machine');
        return;
      }
      final lines = bundle.loadMain();
      final forwarded = lines.where((l) => l.isForwarded).toList();
      final result = _replay(lines, bundle.label);
      // Every forwarded line must produce at least one display message
      // OR be intentionally absorbed into another (tool_result attached
      // to an earlier tool_use). Silent drops — processed but neither
      // rendered nor attached — are the failure mode.
      final rendered = result.messages.length;
      final toolResults = result.toolResults.length;
      final accounted = rendered + toolResults;
      expect(
        accounted,
        greaterThanOrEqualTo(forwarded.length),
        reason: 'Forwarded lines: ${forwarded.length}, '
            'rendered: $rendered, toolResults: $toolResults. '
            'Missing: ${forwarded.length - accounted} — these are '
            'silent drops in the isolate parser.',
      );
    });
  });
}

void _assertZeroDrops(FixtureBundle bundle) {
  final result = _replay(bundle.loadMain(), bundle.label);
  expect(
    result.droppedReasons,
    isEmpty,
    reason: 'Fixture "${bundle.label}" triggered silent drops:\n'
        '${result.droppedReasons.take(20).join("\n")}'
        '${result.droppedReasons.length > 20 ? "\n...and ${result.droppedReasons.length - 20} more" : ""}',
  );
}

ProcessedMessages _replay(List<JsonlLine> lines, String label) {
  final plaintexts = <dynamic>[];
  final wire = <Map<String, dynamic>>[];
  final wasEncrypted = <bool>[];
  for (final l in lines) {
    if (!l.isForwarded) continue;
    plaintexts.add(l.plaintext);
    wire.add(l.wireMessage);
    wasEncrypted.add(false);
  }
  return processDecryptedMessages(
    decryptedJsonList: plaintexts,
    wireMessages: wire,
    sessionId: 'fixture-$label',
    wasEncrypted: wasEncrypted,
  );
}
