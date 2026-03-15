// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/sessions_api.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:riverpod/riverpod.dart';

/// A fake [SessionsApi] that can be configured to succeed or fail.
class _FakeSessionsApi extends SessionsApi {
  _FakeSessionsApi({this.shouldFail = false}) : super();

  final bool shouldFail;
  final List<String> deletedIds = [];
  final Map<String, String> renames = {};

  @override
  Future<void> deleteSession(String sessionId) async {
    if (shouldFail) throw Exception('server error');
    deletedIds.add(sessionId);
  }

  @override
  Future<void> renameSession(
    String sessionId,
    String newName,
  ) async {
    if (shouldFail) throw Exception('server error');
    renames[sessionId] = newName;
  }
}

Session _makeSession(String id, {String name = 'Test Session'}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1_000_000,
    updatedAt: 1_000_000,
    active: true,
    activeAt: 1_000_000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'online',
    metadata: Metadata(host: 'host', path: '/path', name: name),
  );
}

void main() {
  group('SessionsNotifier optimistic deleteSession', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('removes session immediately from state', () async {
      final notifier =
          container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([
        _makeSession('s1'),
        _makeSession('s2'),
      ]);
      notifier.api = _FakeSessionsApi();

      final result = await notifier.deleteSession('s1');

      expect(result, isTrue);
      final state = container.read(sessionsNotifierProvider);
      expect(state.containsKey('s1'), isFalse);
      expect(state.containsKey('s2'), isTrue);
    });

    test('calls deleteSession on the API', () async {
      final fakeApi = _FakeSessionsApi();
      final notifier =
          container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([_makeSession('s1')]);
      notifier.api = fakeApi;

      await notifier.deleteSession('s1');

      expect(fakeApi.deletedIds, contains('s1'));
    });

    test('rolls back deletion when API fails', () async {
      final notifier =
          container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([
        _makeSession('s1'),
        _makeSession('s2'),
      ]);
      notifier.api = _FakeSessionsApi(shouldFail: true);

      final result = await notifier.deleteSession('s1');

      expect(result, isFalse);
      final state = container.read(sessionsNotifierProvider);
      // Session must be restored after rollback.
      expect(state.containsKey('s1'), isTrue);
      expect(state.containsKey('s2'), isTrue);
    });

    test('returns false when API fails', () async {
      final notifier =
          container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([_makeSession('s1')]);
      notifier.api = _FakeSessionsApi(shouldFail: true);

      final result = await notifier.deleteSession('s1');

      expect(result, isFalse);
    });
  });

  group('SessionsNotifier optimistic renameSession', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('updates session name immediately in state', () async {
      final notifier =
          container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([_makeSession('s1', name: 'Old Name')]);
      notifier.api = _FakeSessionsApi();

      final result = await notifier.renameSession('s1', 'New Name');

      expect(result, isTrue);
      final state = container.read(sessionsNotifierProvider);
      expect(state['s1']?.metadata?.name, 'New Name');
    });

    test('calls renameSession on the API', () async {
      final fakeApi = _FakeSessionsApi();
      final notifier =
          container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([_makeSession('s1', name: 'Original')]);
      notifier.api = fakeApi;

      await notifier.renameSession('s1', 'Renamed');

      expect(fakeApi.renames['s1'], 'Renamed');
    });

    test('rolls back name on API failure', () async {
      final notifier =
          container.read(sessionsNotifierProvider.notifier);
      notifier.setSessions([_makeSession('s1', name: 'Original')]);
      notifier.api = _FakeSessionsApi(shouldFail: true);

      final result = await notifier.renameSession('s1', 'Changed');

      expect(result, isFalse);
      final state = container.read(sessionsNotifierProvider);
      // Name must be restored.
      expect(state['s1']?.metadata?.name, 'Original');
    });

    test('returns false when session not found', () async {
      final notifier =
          container.read(sessionsNotifierProvider.notifier);
      notifier.api = _FakeSessionsApi();

      final result = await notifier.renameSession('missing', 'Name');

      expect(result, isFalse);
    });
  });
}
