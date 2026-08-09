import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/services/sync_service.dart';

Map<String, dynamic> _catalog(String slug) => <String, dynamic>{
  'success': true,
  'models': <Map<String, dynamic>>[
    <String, dynamic>{
      'slug': slug,
      'displayName': slug,
      'supportedReasoningEfforts': <String>['medium'],
    },
  ],
};

void main() {
  final sync = Sync();

  setUp(sync.testClearCodexModelsCache);
  tearDown(() {
    sync.testMachineRPCOverride = null;
    sync.testClearCodexModelsCache();
  });

  test('reuses a successful machine catalog across chat refreshes', () async {
    var calls = 0;
    sync.testMachineRPCOverride = (machineId, method, params) async {
      calls++;
      return _catalog('gpt-5.6');
    };

    final first = await sync.machineGetCodexModels(machineId: 'machine-1');
    final second = await sync.machineGetCodexModels(machineId: 'machine-1');

    expect(first.success, isTrue);
    expect(second.models.single.slug, 'gpt-5.6');
    expect(calls, 1);
  });

  test('coalesces concurrent catalog requests for one machine', () async {
    var calls = 0;
    final response = Completer<Map<String, dynamic>>();
    sync.testMachineRPCOverride = (machineId, method, params) {
      calls++;
      return response.future;
    };

    final first = sync.machineGetCodexModels(machineId: 'machine-1');
    final second = sync.machineGetCodexModels(machineId: 'machine-1');
    response.complete(_catalog('gpt-5.6'));

    await Future.wait([first, second]);
    expect(calls, 1);
  });
}
