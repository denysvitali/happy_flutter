import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/inbox_message.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/services/inbox_state_storage.dart';
import 'package:happy_flutter/features/inbox/inbox_providers.dart';
import 'package:happy_flutter/features/inbox/widgets/inbox_kind_style.dart';
import 'package:happy_flutter/features/inbox/widgets/inbox_thread_view.dart';

Session _session(
  String id,
  List<InboxMessage> inbox, {
  bool archived = false,
}) => Session(
  id: id,
  seq: 1,
  createdAt: 1,
  updatedAt: 1,
  active: true,
  activeAt: 1,
  metadataVersion: 1,
  agentStateVersion: 1,
  thinking: false,
  archived: archived,
  metadata: Metadata(inbox: inbox),
);

InboxMessage _msg(
  String id, {
  InboxKind kind = InboxKind.question,
  int createdAt = 1,
  String? sessionId,
}) => InboxMessage(
  id: id,
  kind: kind,
  subject: 'Subject $id',
  body: 'Body $id',
  createdAt: createdAt,
  sessionId: sessionId,
);

void main() {
  group('InboxMessage', () {
    test('InboxMessage_Parse_KeepsValidEntriesOnly', () {
      final parsed = InboxMessage.listFromJson([
        {
          'id': '1',
          'kind': 'question',
          'subject': ' Ship it? ',
          'body': '**Tests pass**',
          'options': ['Yes', '', 3, 'No'],
          'sessionId': 's1',
          'createdAt': 42,
        },
        {'id': '2', 'kind': 'progress', 'subject': 'x', 'createdAt': 1},
        {'id': '', 'kind': 'blocked', 'subject': 'x', 'createdAt': 1},
        {'id': '3', 'kind': 'blocked', 'subject': '', 'createdAt': 1},
        'garbage',
      ])!;
      expect(parsed, hasLength(1));
      expect(parsed.single.subject, 'Ship it?');
      expect(parsed.single.options, ['Yes', 'No']);
      expect(parsed.single.kind, InboxKind.question);
      expect(InboxMessage.listFromJson(null), isNull);
    });

    test('InboxMessage_Metadata_RoundTrips', () {
      final message = _msg('1', kind: InboxKind.goalReached, sessionId: 's');
      final metadata = Metadata.fromJson({
        'host': 'h',
        'inbox': [message.toJson()],
      });
      expect(metadata.inbox, [message]);
      final again = Metadata.fromJson(metadata.toJson());
      expect(again.inbox, [message]);
    });
  });

  group('InboxCatalog', () {
    test('InboxCatalog_FromSessions_SortsNewestFirstAndDropsForeign', () {
      final catalog = InboxCatalog.fromSessions({
        'a': _session('a', [
          _msg('1', createdAt: 10),
          _msg('2', createdAt: 30),
        ]),
        'b': _session('b', [
          _msg('1', createdAt: 20, sessionId: 'b'),
          _msg('9', createdAt: 99, sessionId: 'other'),
        ], archived: true),
      });
      expect(catalog.items.map((i) => i.key), ['a/2', 'b/1', 'a/1']);
      expect(catalog.items[1].archived, isTrue);
    });

    test('InboxCatalog_Equality_IgnoresUnrelatedSessionChurn', () {
      final a = InboxCatalog.fromSessions({
        'a': _session('a', [_msg('1')]),
      });
      final b = InboxCatalog.fromSessions({
        'a': _session('a', [_msg('1')]).copyWith(thinking: true, seq: 99),
      });
      expect(a, b);
    });
  });

  group('InboxMessageState', () {
    test('InboxMessageState_Json_RoundTrips', () {
      const state = InboxMessageState(
        read: true,
        done: true,
        reply: 'yes',
        repliedAt: 5,
      );
      final restored = InboxMessageState.fromJson(state.toJson());
      expect(restored.read, isTrue);
      expect(restored.done, isTrue);
      expect(restored.reply, 'yes');
      expect(restored.replied, isTrue);
      expect(InboxMessageState.fromJson('x').read, isFalse);
    });

    test('InboxItem_NeedsReply_OnlyForUnansweredQuestionsAndBlockers', () {
      final session = _session('s', const []);
      final question = InboxItem.from(session, _msg('1'));
      final goal = InboxItem.from(
        session,
        _msg('2', kind: InboxKind.goalReached),
      );
      expect(inboxItemNeedsReply(question, InboxMessageState.initial), isTrue);
      expect(inboxItemNeedsReply(goal, InboxMessageState.initial), isFalse);
      expect(
        inboxItemNeedsReply(question, const InboxMessageState(repliedAt: 1)),
        isFalse,
      );
      expect(
        inboxItemNeedsReply(question, const InboxMessageState(done: true)),
        isFalse,
      );
    });
  });

  test('inboxReplyText_QuotesSubject', () {
    expect(
      inboxReplyText(_msg('1'), '  Yes, ship it \n'),
      'Re: Subject 1\n\nYes, ship it',
    );
  });

  test('inboxSnippet_StripsMarkdown', () {
    expect(
      inboxSnippet(
        '# Done\n\n- **All** tests [pass](http://x)\n```\ncode\n```',
      ),
      'Done All tests pass',
    );
  });
}
