import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression: every per-session `fetchMessages` [InvalidateSync] must come
/// from one factory.
///
/// Four call sites used to build them by hand (session visible, socket
/// reconnect refresh, session restore, lazy recreate on a socket event) and
/// three of them drifted back to `maxRetries: 0`. Message-page requests opt
/// out of the HTTP retry interceptor (`disableRetry: true`), so that left
/// them with no recovery layer at all: one transport stall permanently
/// discarded a page.
void main() {
  test('messagesSync is constructed in exactly one place', () {
    final dir = Directory('lib/core/services');
    expect(dir.existsSync(), isTrue, reason: 'run from the package root');

    final sites = <String>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final line in source.split('\n')) {
        if (line.contains("name: 'fetchMessages'")) {
          sites.add(entity.path);
        }
      }
    }

    expect(
      sites,
      ['lib/core/services/sync_service.dart'],
      reason:
          'build message syncs with Sync._createMessagesSync so no call '
          'site can drift back to maxRetries: 0',
    );

    final syncService = File(
      'lib/core/services/sync_service.dart',
    ).readAsStringSync();
    expect(
      syncService.contains('maxRetries: _messagesSyncMaxRetries'),
      isTrue,
      reason: 'the factory must use the shared retry budget constant',
    );
  });
}
