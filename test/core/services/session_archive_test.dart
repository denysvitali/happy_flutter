import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/api/sessions_api.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/session_archive.dart';

class _RecordingArchiveApi extends SessionsApi {
  _RecordingArchiveApi(this.calls);
  final List<String> calls;

  @override
  Future<void> setSessionArchived(String id, bool archived) async {
    calls.add('archive:$id:$archived');
  }
}

Session _session({required bool active, String presence = 'offline'}) =>
    Session(
      id: 's1',
      seq: 0,
      createdAt: 0,
      updatedAt: 0,
      active: active,
      activeAt: 0,
      metadataVersion: 0,
      agentStateVersion: 0,
      thinking: false,
      presence: presence,
    );

void main() {
  test('archiving a live session stops its process first', () async {
    final calls = <String>[];
    await archiveSessionStoppingProcess(
      's1',
      api: _RecordingArchiveApi(calls),
      session: _session(active: true),
      stopProcess: (id) async => calls.add('stop:$id'),
    );
    expect(calls, ['stop:s1', 'archive:s1:true']);
  });

  test('archiving an online session stops its process first', () async {
    final calls = <String>[];
    await archiveSessionStoppingProcess(
      's1',
      api: _RecordingArchiveApi(calls),
      session: _session(active: false, presence: 'online'),
      stopProcess: (id) async => calls.add('stop:$id'),
    );
    expect(calls, ['stop:s1', 'archive:s1:true']);
  });

  test('archiving a session without a process only archives', () async {
    final calls = <String>[];
    await archiveSessionStoppingProcess(
      's1',
      api: _RecordingArchiveApi(calls),
      session: _session(active: false),
      stopProcess: (id) async => calls.add('stop:$id'),
    );
    expect(calls, ['archive:s1:true']);
  });

  test('a failed stop still records the archive request', () async {
    final calls = <String>[];
    await archiveSessionStoppingProcess(
      's1',
      api: _RecordingArchiveApi(calls),
      session: _session(active: true),
      stopProcess: (_) async => throw StateError('machine offline'),
    );
    expect(calls, ['archive:s1:true']);
  });
}
