import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/folder_view_cards.dart';

Session _session({String id = 's1', String path = '/repo/happy'}) {
  return Session(
    id: id,
    seq: 1,
    createdAt: 1700000000000,
    updatedAt: 1700000000000,
    active: true,
    activeAt: 1700000000000,
    metadataVersion: 1,
    agentStateVersion: 1,
    thinking: false,
    presence: 'online',
    metadata: Metadata(path: path, host: 'mac'),
  );
}

void main() {
  group('FolderOverviewCard', () {
    testWidgets('renders folder name, state breakdown, and unread badge', (
      tester,
    ) async {
      const header = SessionFolderHeader(
        displayPath: '~/projects/happy',
        machineName: 'Work Mac',
        sessionCount: 4,
        activeSessionCount: 2,
        inactiveSessionCount: 2,
        folderKey: 'm1:/projects/happy',
        latestActivityAt: 1,
        unreadCount: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FolderOverviewCard(header: header, onTap: () {}),
          ),
        ),
      );

      expect(find.text('happy'), findsOneWidget);
      expect(find.text('2 active • 2 archived'), findsOneWidget);
      expect(find.text('4 sessions'), findsNothing);
      expect(find.text('Work Mac • 4 sessions'), findsNothing);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('calls onTap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FolderOverviewCard(
              header: const SessionFolderHeader(
                displayPath: '~/projects/happy',
                machineName: 'Work Mac',
                sessionCount: 1,
                activeSessionCount: 1,
                folderKey: 'm1:/projects/happy',
              ),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FolderOverviewCard));
      expect(tapped, isTrue);
    });

    testWidgets('omits an empty side of the state breakdown', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FolderOverviewCard(
              header: const SessionFolderHeader(
                displayPath: '~/projects/happy',
                machineName: 'Work Mac',
                sessionCount: 3,
                activeSessionCount: 3,
                folderKey: 'm1:/projects/happy',
              ),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('3 active'), findsOneWidget);
      expect(find.textContaining('archived'), findsNothing);
    });
  });

  group('FolderSessionRow', () {
    testWidgets('renders as a grouped chat row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderSessionGroup(
              children: [
                FolderSessionRow(
                  session: _session(),
                  showFlavorIcon: false,
                  onTap: () {},
                  onLongPress: () {},
                  lastMessagePreview: 'Latest message preview',
                  lastMessageRole: 'assistant',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(FolderSessionGroup), findsOneWidget);
      expect(find.text('happy'), findsOneWidget);
      expect(find.text('Latest message preview'), findsOneWidget);
    });

    testWidgets('calls onTap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderSessionRow(
              session: _session(),
              showFlavorIcon: false,
              onTap: () => tapped = true,
              onLongPress: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FolderSessionRow));
      expect(tapped, isTrue);
    });

    testWidgets('uses a supplied disambiguated session name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FolderSessionRow(
              session: _session(),
              displayName: 'happy · abc123',
              showFlavorIcon: false,
              onTap: () {},
              onLongPress: () {},
            ),
          ),
        ),
      );

      expect(find.text('happy · abc123'), findsOneWidget);
      expect(find.text('happy'), findsNothing);
    });
  });
}
