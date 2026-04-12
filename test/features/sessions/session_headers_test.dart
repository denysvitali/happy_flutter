import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/utils/session_utils.dart';
import 'package:happy_flutter/features/sessions/widgets/session_headers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── SectionHeader ───────────────────────────────────────

  group('SectionHeader', () {
    testWidgets('renders title text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SectionHeader(title: 'Active Sessions')),
        ),
      );

      expect(find.text('Active Sessions'), findsOneWidget);
    });

    testWidgets('applies uppercase label style', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SectionHeader(title: 'Archived')),
        ),
      );

      final text = tester.widget<Text>(find.text('Archived'));
      // The labelSmall style should have fontWeight w600
      expect(text.style?.fontWeight, FontWeight.w600);
    });
  });

  // ─── PathHeader ──────────────────────────────────────────

  group('PathHeader', () {
    testWidgets('renders path basename uppercase', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PathHeader(
              path: '/home/user/projects',
              sessionCount: 3,
              isCollapsed: false,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('PROJECTS'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('calls onToggle when tapped', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PathHeader(
              path: '/home/dev',
              sessionCount: 1,
              isCollapsed: false,
              onToggle: () => toggled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('DEV'));
      expect(toggled, isTrue);
    });

    testWidgets('shows rotation for collapsed state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PathHeader(
              path: '/test',
              sessionCount: 2,
              isCollapsed: true,
              onToggle: () {},
            ),
          ),
        ),
      );

      // The AnimatedRotation widget should exist
      expect(find.byType(AnimatedRotation), findsOneWidget);
    });
  });

  // ─── CollapsibleDateHeader ───────────────────────────────

  group('CollapsibleDateHeader', () {
    testWidgets('renders date and count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CollapsibleDateHeader(
              date: 'Today',
              sessionCount: 5,
              isCollapsed: false,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('calls onToggle when tapped', (tester) async {
      var toggled = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CollapsibleDateHeader(
              date: 'Yesterday',
              sessionCount: 2,
              isCollapsed: true,
              onToggle: () => toggled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Yesterday'));
      expect(toggled, isTrue);
    });
  });

  // ─── CollapsibleFolderHeader ─────────────────────────────

  group('CollapsibleFolderHeader', () {
    testWidgets('renders folder info', (tester) async {
      final header = SessionFolderHeader(
        displayPath: '~/projects/app',
        machineName: 'dev-machine',
        sessionCount: 4,
        folderKey: 'machine-1:~/projects/app',
        activeSessionCount: 2,
        inactiveSessionCount: 2,
        unreadCount: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CollapsibleFolderHeader(
              header: header,
              isCollapsed: false,
              onToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('~/projects/app'), findsOneWidget);
      expect(find.text('dev-machine'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('2 active • 2 archived'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('calls onToggle when tapped', (tester) async {
      var toggled = false;
      final header = SessionFolderHeader(
        displayPath: '/test',
        machineName: 'test-machine',
        sessionCount: 1,
        folderKey: 'm1:/test',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CollapsibleFolderHeader(
              header: header,
              isCollapsed: false,
              onToggle: () => toggled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('/test'));
      expect(toggled, isTrue);
    });
  });

  // ─── ArchiveSectionHeader ────────────────────────────────

  group('ArchiveSectionHeader', () {
    testWidgets('renders history title with count', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: _localizationsDelegates,
          supportedLocales: _supportedLocales,
          home: const Scaffold(
            body: ArchiveSectionHeader(
              count: 10,
              grouping: ArchivedGrouping.date,
              onGroupingChanged: _noopGrouping,
            ),
          ),
        ),
      );

      expect(find.textContaining('History'), findsWidgets);
    });

    testWidgets('renders grouping toggle icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: _localizationsDelegates,
          supportedLocales: _supportedLocales,
          home: const Scaffold(
            body: ArchiveSectionHeader(
              count: 5,
              grouping: ArchivedGrouping.date,
              onGroupingChanged: _noopGrouping,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('calls onGroupingChanged when folder tapped', (tester) async {
      ArchivedGrouping? changed;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: _localizationsDelegates,
          supportedLocales: _supportedLocales,
          home: Scaffold(
            body: ArchiveSectionHeader(
              count: 5,
              grouping: ArchivedGrouping.date,
              onGroupingChanged: (g) => changed = g,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.folder_outlined));
      expect(changed, ArchivedGrouping.folder);
    });
  });
}

// ─── Helpers ──────────────────────────────────────────────

void _noopGrouping(ArchivedGrouping _) {}

const _localizationsDelegates = AppLocalizations.localizationsDelegates;

const _supportedLocales = AppLocalizations.supportedLocales;
