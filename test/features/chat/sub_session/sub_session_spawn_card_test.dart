import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/derived_view_providers.dart';
import 'package:happy_flutter/features/chat/message_widget.dart';
import 'package:happy_flutter/features/chat/sub_session/sub_session_projection.dart';
import 'package:happy_flutter/features/chat/sub_session/sub_session_spawn_card.dart';
import 'package:happy_flutter/features/chat/tools/views/task_view.dart';

Map<String, dynamic> _call({
  String callId = 'call-1',
  String childId = 'child-1',
  int seq = 1,
  String state = 'running',
  Object? result,
  String? resultStatus,
}) => {
  'id': 'msg-$callId',
  'toolUseId': callId,
  'kind': 'tool-call',
  'name': 'Agent',
  'seq': seq,
  'createdAt': DateTime.now().millisecondsSinceEpoch,
  'state': state,
  'result': ?result,
  'resultStatus': ?resultStatus,
  'input': {
    'description': 'Fix the flaky test',
    'prompt': 'Please investigate the flaky login test and fix it.',
    'subagent_type': 'happy-session',
    'agentId': childId,
    'sessionId': childId,
  },
};

Session _child({bool thinking = false, bool archived = false}) => Session(
  id: 'child-1',
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: !archived,
  activeAt: DateTime.now().millisecondsSinceEpoch,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: thinking,
  archived: archived,
  presence: archived ? 'offline' : 'online',
  metadata: const Metadata(
    path: '/work/happy_flutter',
    repoUrl: 'https://github.com/acme/happy_flutter',
    summary: Summary(text: 'Flaky login test', updatedAt: 1),
  ),
);

Widget _app(Widget child, {Session? session, String childId = 'child-1'}) =>
    ProviderScope(
      overrides: [sessionByIdProvider(childId).overrideWithValue(session)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  testWidgets('in progress: live child state and waiting notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(SubSessionSpawnCard(call: _call()), session: _child(thinking: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sub-session'), findsOneWidget);
    expect(find.text('Fix the flaky test'), findsOneWidget);
    expect(find.text('Working'), findsOneWidget);
    expect(find.text('Flaky login test · acme/happy_flutter'), findsOneWidget);
    expect(find.text('Waiting for the sub-session to reply…'), findsOneWidget);
    expect(find.text('Reply'), findsNothing);
  });

  testWidgets('completed: reply as markdown and opens the child chat', (
    tester,
  ) async {
    String? opened;
    await tester.pumpWidget(
      _app(
        SubSessionSpawnCard(
          call: _call(state: 'completed', result: 'Fixed **the race**.'),
          onOpenSession: (id) => opened = id,
        ),
        session: _child(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('Reply'), findsOneWidget);
    expect(find.textContaining('the race', findRichText: true), findsWidgets);
    expect(find.text('Waiting for the sub-session to reply…'), findsNothing);

    await tester.tap(find.text('Open session'));
    expect(opened, 'child-1');
  });

  testWidgets('prompt is collapsible', (tester) async {
    await tester.pumpWidget(
      _app(SubSessionSpawnCard(call: _call()), session: _child()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsNothing);

    await tester.tap(find.text('Prompt'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is SelectableText &&
            w.data == 'Please investigate the flaky login test and fix it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('long replies collapse behind Show more', (tester) async {
    final reply = List.generate(40, (i) => 'Line $i').join('\n\n');
    await tester.pumpWidget(
      _app(
        SubSessionSpawnCard(
          call: _call(state: 'completed', result: reply),
        ),
        session: _child(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Show more'), findsOneWidget);

    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('failed and unknown outcomes are explicit', (tester) async {
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            SubSessionSpawnCard(
              call: _call(state: 'error', result: 'spawn refused'),
            ),
            SubSessionSpawnCard(
              call: _call(
                callId: 'call-2',
                seq: 2,
                state: 'completed',
                resultStatus: 'unknown',
              ),
            ),
          ],
        ),
        session: _child(archived: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The sub-session turn failed'), findsOneWidget);
    expect(
      find.textContaining('spawn refused', findRichText: true),
      findsWidgets,
    );
    expect(
      find.text(
        'Outcome unknown. Open the sub-session to check what happened.',
      ),
      findsOneWidget,
    );
    expect(find.text('Archived'), findsNWidgets(2));
  });

  testWidgets('follow-up turns read as one thread', (tester) async {
    final spawn = _call(state: 'completed', result: 'First pass done');
    final followUp = _call(callId: 'call-2', seq: 5);
    final transcript = [spawn, followUp];
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            SubSessionSpawnCard(call: spawn, messages: transcript),
            SubSessionSpawnCard(call: followUp, messages: transcript),
          ],
        ),
        session: _child(thinking: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sub-session · Follow-up #2'), findsOneWidget);
    expect(find.text('2 turns'), findsOneWidget);
    expect(find.byIcon(Icons.subdirectory_arrow_right_rounded), findsOneWidget);
  });

  testWidgets('unknown child is fetched, then shown as unavailable', (
    tester,
  ) async {
    final fetched = <String>[];
    String? opened;
    await tester.pumpWidget(
      _app(
        SubSessionSpawnCard(
          call: _call(childId: 'missing'),
          fetchSession: (id) async {
            fetched.add(id);
            return null;
          },
          onOpenSession: (id) => opened = id,
        ),
        childId: 'missing',
      ),
    );
    await tester.pumpAndSettle();

    expect(fetched, ['missing']);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(
      find.text('This sub-session is not available on this device'),
      findsOneWidget,
    );
    final button = tester.widget<TextButton>(
      find.ancestor(
        of: find.text('Open session'),
        matching: find.byWidgetPredicate((w) => w is TextButton),
      ),
    );
    expect(button.onPressed, isNull);
    await tester.tap(find.text('Fix the flaky test'));
    expect(opened, isNull);
  });

  testWidgets('MessageWidget renders spawns with the sub-session card', (
    tester,
  ) async {
    final call = _call();
    expect(isHappySubSessionSpawn(call), isTrue);
    await tester.pumpWidget(
      _app(
        MessageWidget(
          messageData: call,
          isFromCurrentUser: false,
          animate: false,
          sessionId: 'parent',
          messages: [call],
        ),
        session: _child(thinking: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SubSessionSpawnCard), findsOneWidget);
    expect(find.byType(TaskView), findsNothing);
  });
}
