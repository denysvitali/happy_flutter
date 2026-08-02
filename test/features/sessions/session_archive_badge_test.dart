import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/features/sessions/widgets/archived_session_card.dart';
import 'package:happy_flutter/features/sessions/widgets/session_cards.dart';

/// Finding 5b: the pending-archive label used to render in the trailing
/// column directly beneath the timestamp, so it read as date metadata.
/// It is now a badge next to the session name.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('archive countdown renders as a badge beside the name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SessionCard(
            session: _session(id: 'arch-1', path: '/home/project'),
            showFlavorIcon: false,
            archiveCountdownLabel: 'Archive pending',
          ),
        ),
      ),
    );

    expect(find.byType(ArchiveCountdownBadge), findsOneWidget);
    expect(find.text('Archive pending'), findsOneWidget);

    // It shares the name row rather than the trailing timestamp column.
    final nameRow = find
        .ancestor(
          of: find.byType(ArchiveCountdownBadge),
          matching: find.byType(Row),
        )
        .first;
    expect(
      find.descendant(of: nameRow, matching: find.text('project')),
      findsOneWidget,
    );
  });

  testWidgets('no badge is rendered without a countdown label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SessionCard(
            session: _session(id: 'arch-2', path: '/home/project'),
            showFlavorIcon: false,
          ),
        ),
      ),
    );

    expect(find.byType(ArchiveCountdownBadge), findsNothing);
  });
}

Session _session({required String id, required String path}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1,
    updatedAt: 1,
    active: false,
    activeAt: 1,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'offline',
    metadata: Metadata(host: 'localhost', path: path),
  );
}
