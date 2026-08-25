import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/native/generated/api/sidechain_api.dart';
import 'package:happy_flutter/core/native/native_core.dart';
import 'package:happy_flutter/core/services/sidechain_grouper.dart';

/// Contract coverage for the optional Rust sidechain planner.
///
/// The native assertions are guarded because platforms without the shared
/// library must continue to use the existing Dart grouper.
void main() {
  setUp(() async {
    NativeCore.instance.debugReset();
    await NativeCore.instance.ensureInitialized();
  });

  tearDown(NativeCore.instance.debugReset);

  SidechainRow task(String id, String uuid, {bool topLevel = true}) =>
      SidechainRow(
        id: id,
        uuid: uuid,
        parentUuid: '',
        parentToolUseId: '',
        toolUseId: '',
        prompt: '',
        agentId: '',
        kind: 'tool-call',
        name: 'Task',
        isSidechain: false,
        isTaskEvent: false,
        topLevel: topLevel,
        ancestorTaskId: topLevel ? '' : 'outer',
        rootUuids: const [],
      );

  SidechainRow child(
    String id,
    String uuid,
    String parentUuid, {
    bool topLevel = true,
  }) => SidechainRow(
    id: id,
    uuid: uuid,
    parentUuid: parentUuid,
    parentToolUseId: '',
    toolUseId: '',
    prompt: '',
    agentId: '',
    kind: 'text',
    name: '',
    isSidechain: true,
    isTaskEvent: false,
    topLevel: topLevel,
    ancestorTaskId: '',
    rootUuids: const [],
  );

  test(
    'native plan is index-aligned for direct, transitive, and orphan rows',
    () {
      if (!NativeCore.instance.isAvailable) return;
      final assignments = NativeCore.instance.planSidechainGrouping(
        rows: [
          task('t1', 'task-uuid'),
          child('c2', 'c2-uuid', 'c1-uuid'),
          child('c1', 'c1-uuid', 'task-uuid'),
          child('orphan', 'orphan-uuid', 'missing-uuid'),
        ],
      );

      expect(assignments, isNotNull);
      expect(assignments, <String?>[null, 't1', 't1', null]);
    },
  );

  test('native plan routes a new child to an existing nested Task', () {
    if (!NativeCore.instance.isAvailable) return;
    final assignments = NativeCore.instance.planSidechainGrouping(
      rows: [
        task('outer', 'outer-uuid'),
        task('inner', 'inner-uuid', topLevel: false),
        child('c1', 'c1-uuid', 'inner-uuid'),
      ],
    );

    expect(assignments, <String?>[null, null, 'inner']);
  });

  test('native planner is optional and returns null when disabled', () {
    NativeCore.instance.debugSetAvailable(available: false);
    expect(
      NativeCore.instance.planSidechainGrouping(rows: [task('t1', 'u1')]),
      isNull,
    );
  });

  test('production grouper applies the native plan without changing shape', () {
    if (!NativeCore.instance.isAvailable) return;
    final messages = <Map<String, dynamic>>[
      {
        'id': 'task-1',
        'uuid': 'task-uuid',
        'kind': 'tool-call',
        'name': 'Task',
      },
      {
        'id': 'root-1',
        'uuid': 'root-uuid',
        'parentUuid': 'task-uuid',
        'kind': 'sidechain-root',
        'isSidechain': true,
      },
      {
        'id': 'child-1',
        'uuid': 'child-uuid',
        'parentUuid': 'root-uuid',
        'isSidechain': true,
      },
    ];

    final result = SidechainGrouper().groupMessages(messages);

    expect(result, isNotNull);
    expect(result!.messages.map((message) => message['id']), ['task-1']);
    expect(
      (result.messages.single['children'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((message) => message['id']),
      ['child-1'],
    );
  });
}
