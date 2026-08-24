import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/derived_view_providers.dart';
import 'package:happy_flutter/core/providers/sessions_notifier.dart';

/// Progressive-lag remediation, third pass 2026-08-24.
///
/// The per-id family providers used to be non-autoDispose: riverpod keeps
/// every such element alive for the process lifetime, so one element per
/// session/machine id ever rendered accumulated forever — slow heap growth
/// proportional to browsing. These tests pin the autoDispose lifecycle flag
/// (`isAutoDispose` is riverpod's public contract for "dispose me when the
/// last listener goes away") and that values still resolve through the
/// families afterwards.
void main() {
  test('every per-id derived family is autoDispose', () {
    // Per-argument instances carry the flag, not just the family object.
    expect(sessionByIdProvider('probe').isAutoDispose, isTrue,
        reason: 'sessionById must not pin one element per id forever');
    expect(machineByIdProvider('probe').isAutoDispose, isTrue,
        reason: 'machineById must not pin one element per id forever');
    expect(recentPathsForMachineProvider('probe').isAutoDispose, isTrue,
        reason: 'recentPathsForMachine must not pin one element per id '
            'forever');
    expect(sessionUiEntryProvider('probe').isAutoDispose, isTrue,
        reason: 'sessionUiEntry must not pin one element per id forever');
  });

  test('values still resolve correctly through the autoDispose families', () {
    final container = ProviderContainer(overrides: [
      sessionsNotifierProvider.overrideWith(() => _FixedSessionsNotifier()),
    ]);
    addTearDown(container.dispose);

    expect(container.read(sessionByIdProvider('a'))!.id, 'a');
    expect(container.read(sessionByIdProvider('missing')), isNull);
  });
}

class _FixedSessionsNotifier extends SessionsNotifier {
  @override
  Map<String, Session> build() {
    return {
      'a': Session(
        id: 'a',
        seq: 1,
        createdAt: 1,
        updatedAt: 1,
        active: true,
        activeAt: 1,
        metadataVersion: 1,
        agentStateVersion: 1,
        presence: 'offline',
        thinking: false,
        lastSeq: 1,
      ),
    };
  }
}
