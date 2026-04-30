import 'package:happy_flutter/core/models/local_settings.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/auto_archive_service.dart';
import 'package:test/test.dart';

Session _session({
  required int updatedAt,
  int? createdAt,
  bool archived = false,
  bool active = false,
  bool thinking = false,
  String presence = 'offline',
  String? draft,
  AgentState? agentState,
}) {
  return Session(
    id: 'session-1',
    seq: 1,
    createdAt: createdAt ?? updatedAt,
    updatedAt: updatedAt,
    active: active,
    activeAt: updatedAt,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    archived: archived,
    presence: presence,
    draft: draft,
    agentState: agentState,
  );
}

void main() {
  group('AutoArchiveService', () {
    test('supports minute-based idle archive durations', () {
      const settings = AutoArchiveSettings(autoArchiveIdleAfterDays: -120);

      expect(
        AutoArchiveService.idleArchiveDuration(settings),
        const Duration(hours: 2),
      );
      expect(
        AutoArchiveService.encodeIdleDuration(const Duration(minutes: 30)),
        -30,
      );
    });

    test('keeps legacy positive idle durations as days', () {
      const settings = AutoArchiveSettings(autoArchiveIdleAfterDays: 7);

      expect(
        AutoArchiveService.idleArchiveDuration(settings),
        const Duration(days: 7),
      );
    });

    test('archives offline idle sessions after configured duration', () {
      const now = 10 * 60 * 60 * 1000;
      final session = _session(updatedAt: now - 3 * 60 * 60 * 1000);

      expect(
        AutoArchiveService.shouldArchiveSession(
          session: session,
          settings: AutoArchiveService.defaultSettings,
          nowMs: now,
          isPinned: false,
          hasUnsettledSend: false,
        ),
        isTrue,
      );
    });

    test('does not archive protected sessions', () {
      const now = 10 * 60 * 60 * 1000;
      final oldUpdatedAt = now - 3 * 60 * 60 * 1000;
      final requestState = AgentState(
        requests: {'request-1': const RequestInfo(tool: 'Edit')},
      );

      for (final session in [
        _session(updatedAt: oldUpdatedAt, active: true),
        _session(updatedAt: oldUpdatedAt, presence: 'online'),
        _session(updatedAt: oldUpdatedAt, thinking: true),
        _session(updatedAt: oldUpdatedAt, draft: 'unfinished'),
        _session(updatedAt: oldUpdatedAt, agentState: requestState),
      ]) {
        expect(
          AutoArchiveService.shouldArchiveSession(
            session: session,
            settings: AutoArchiveService.defaultSettings,
            nowMs: now,
            isPinned: false,
            hasUnsettledSend: false,
          ),
          isFalse,
        );
      }

      expect(
        AutoArchiveService.shouldArchiveSession(
          session: _session(updatedAt: oldUpdatedAt),
          settings: AutoArchiveService.defaultSettings,
          nowMs: now,
          isPinned: true,
          hasUnsettledSend: false,
        ),
        isFalse,
      );

      expect(
        AutoArchiveService.shouldArchiveSession(
          session: _session(updatedAt: oldUpdatedAt),
          settings: AutoArchiveService.defaultSettings,
          nowMs: now,
          isPinned: false,
          hasUnsettledSend: true,
        ),
        isFalse,
      );
    });

    test('detects unsettled optimistic send statuses', () {
      expect(
        AutoArchiveService.hasUnsettledSend([
          {'sendStatus': 'sent'},
          {'sendStatus': 'pending'},
        ]),
        isTrue,
      );
      expect(
        AutoArchiveService.hasUnsettledSend([
          {'sendStatus': 'sent'},
          {'role': 'agent'},
        ]),
        isFalse,
      );
    });
  });
}
