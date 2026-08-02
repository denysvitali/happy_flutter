import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_status_dot.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/utils/session_status.dart';
import 'package:happy_flutter/features/sessions/widgets/session_badges.dart';

/// Finding 2: session status was communicated by a coloured dot only.
/// Each state now has its own shape and a localized semantics label.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpIndicator(WidgetTester tester, Session session) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SessionStatusIndicator(status: getSessionStatus(session)),
        ),
      ),
    );
  }

  testWidgets('offline renders a hollow ring, not a filled dot', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await pumpIndicator(
      tester,
      _session(id: 'off-1', presence: 'offline', active: false),
    );

    expect(find.byType(AppStatusDot), findsNothing);
    expect(find.bySemanticsLabel('Offline'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('online renders a filled dot with an Online label', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await pumpIndicator(tester, _session(id: 'on-1', presence: 'online'));

    expect(find.byType(AppStatusDot), findsOneWidget);
    expect(find.bySemanticsLabel('Online'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('thinking is announced rather than shown by colour', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await pumpIndicator(
      tester,
      _session(id: 'think-1', presence: 'online', thinking: true),
    );

    expect(find.bySemanticsLabel('Thinking'), findsOneWidget);

    handle.dispose();
  });
}

Session _session({
  required String id,
  required String presence,
  bool active = true,
  bool thinking = false,
}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: active,
    activeAt: 1,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: thinking,
    presence: presence,
    metadata: Metadata(host: 'localhost', path: '/p'),
  );
}
