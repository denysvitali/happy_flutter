import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/chat/widgets/chat_app_bar.dart';

Session _session() => Session.fromJson(<String, dynamic>{
  'id': 's1',
  'seq': 1,
  'createdAt': 1,
  'updatedAt': 1,
  'active': true,
  'activeAt': 1,
  'metadataVersion': 1,
  'agentStateVersion': 1,
  'thinking': false,
  'archived': false,
  'metadata': <String, dynamic>{
    'path': '/Users/alex/personal/side-project',
    'host': 'macbook-pro.local',
  },
  'agentState': null,
  'presence': 'online',
});

class _StubSessionsNotifier extends SessionsNotifier {
  _StubSessionsNotifier(this._sessions);
  final Map<String, Session> _sessions;
  @override
  Map<String, Session> build() => _sessions;
  @override
  void loadFromSync() {}
  @override
  Future<void> refreshFromSync({bool includeMachines = false}) async {}
}

Widget _harness({
  required Session? session,
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: ChatAppBar(
          session: session,
          // What ChatScreen passes before it has loaded the session.
          sessionTitle: 'Chat',
          sessionId: 's1',
          statusChips: const [],
          onMenuTap: () {},
          onInfoTap: () {},
        ),
      ),
    ),
  );
}

void main() {
  group('ChatAppBar title fallback', () {
    testWidgets('uses the store session while the chat screen is loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          session: null,
          overrides: [
            sessionsNotifierProvider.overrideWith(
              () => _StubSessionsNotifier({'s1': _session()}),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('side-project'), findsOneWidget);
      expect(find.text('Chat'), findsNothing);
      expect(
        find.textContaining('side-project', findRichText: true),
        findsWidgets,
      );
      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('falls back to the generic title for an unknown session', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          session: null,
          overrides: [
            sessionsNotifierProvider.overrideWith(
              () => _StubSessionsNotifier(const {}),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Chat'), findsOneWidget);
    });
  });
}
