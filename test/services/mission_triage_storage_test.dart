import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/mission_triage_storage.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';

class _FakeTriageStorage extends MMKVStorage {
  _FakeTriageStorage() : super.testConstructor();

  final Map<String, String> data = {};

  @override
  String? getString(String key) => data[key];

  @override
  void setString(String key, String value) => data[key] = value;
}

void main() {
  late _FakeTriageStorage storage;
  late ProviderContainer container;

  setUp(() {
    storage = _FakeTriageStorage();
    container = ProviderContainer(
      overrides: [
        missionTriageProvider.overrideWith(
          () => MissionTriageNotifier(storage: storage),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  MissionTriageNotifier get notifier =>
      container.read(missionTriageProvider.notifier);

  test('starts empty', () {
    final state = container.read(missionTriageProvider);
    expect(state.pinnedSessions, isEmpty);
    expect(state.snoozedUntil, isEmpty);
    expect(state.mutedFolders, isEmpty);
  });

  test('togglePin adds then removes a session', () {
    notifier.togglePin('s1');
    expect(container.read(missionTriageProvider).isPinned('s1'), isTrue);

    notifier.togglePin('s1');
    expect(container.read(missionTriageProvider).isPinned('s1'), isFalse);
  });

  test('snooze is active until the window lapses', () {
    notifier.snooze('s1');
    final until = container.read(missionTriageProvider).snoozedUntil['s1']!;
    expect(
      container.read(missionTriageProvider).isSnoozed('s1', nowMs: until - 1),
      isTrue,
    );
    expect(
      container.read(missionTriageProvider).isSnoozed('s1', nowMs: until + 1),
      isFalse,
    );

    notifier.unsnooze('s1');
    expect(
      container.read(missionTriageProvider).isSnoozed('s1', nowMs: until - 1),
      isFalse,
    );
  });

  test('toggleMute parks a folder and back', () {
    notifier.toggleMute('m1:/repo');
    expect(
      container.read(missionTriageProvider).isMuted('m1:/repo'),
      isTrue,
    );

    notifier.toggleMute('m1:/repo');
    expect(
      container.read(missionTriageProvider).isMuted('m1:/repo'),
      isFalse,
    );
  });

  test('triage decisions persist across container instances', () {
    notifier.togglePin('s1');
    notifier.snooze('s2');
    notifier.toggleMute('m1:/repo');

    final second = ProviderContainer(
      overrides: [
        missionTriageProvider.overrideWith(
          () => MissionTriageNotifier(storage: storage),
        ),
      ],
    );
    addTearDown(second.dispose);

    final restored = second.read(missionTriageProvider);
    expect(restored.isPinned('s1'), isTrue);
    expect(restored.snoozedUntil.containsKey('s2'), isTrue);
    expect(restored.isMuted('m1:/repo'), isTrue);
  });

  test('a corrupt payload resets to empty instead of throwing', () {
    storage.data['mission-control-triage'] = '{not json';
    final second = ProviderContainer(
      overrides: [
        missionTriageProvider.overrideWith(
          () => MissionTriageNotifier(storage: storage),
        ),
      ],
    );
    addTearDown(second.dispose);

    expect(second.read(missionTriageProvider), const MissionTriageState());
  });
}
