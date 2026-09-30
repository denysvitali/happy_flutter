import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/sessions/widgets/stream_wall.dart';

/// Focus queue sessions already say "something happened here"; the Live
/// wire must not repeat them as a second row.
void main() {
  WireEvent event(String id, String name, int atMs) => WireEvent(
    sessionId: id,
    sessionName: name,
    workspaceKey: 'm:/repo',
    atMs: atMs,
    kind: WireEventKind.inbound,
    detail: 'update from $name',
  );

  Future<void> pump(WidgetTester tester, {required Set<String> hidden}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreamWallSection(
              events: [
                event('queued', 'Queued session', 3000),
                event('other', 'Other session', 2000),
              ],
              hiddenSessionIds: hidden,
              streamCount: 2,
              onOpenSession: (_) {},
              onPeekSession: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('skips sessions that the Focus queue already shows', (
    tester,
  ) async {
    await pump(tester, hidden: {'queued'});

    expect(
      find.textContaining('Queued session', findRichText: true),
      findsNothing,
    );
    expect(
      find.textContaining('Other session', findRichText: true),
      findsOneWidget,
    );
    // Header count reflects the deduped list, not the raw buffer.
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('keeps every row when nothing is hidden', (tester) async {
    await pump(tester, hidden: const <String>{});

    expect(
      find.textContaining('Queued session', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Other session', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('falls back to the watching hint when all rows dedupe', (
    tester,
  ) async {
    await pump(tester, hidden: {'queued', 'other'});

    expect(
      find.textContaining('Queued session', findRichText: true),
      findsNothing,
    );
    expect(find.textContaining('Watching 2 streams'), findsOneWidget);
  });
}
