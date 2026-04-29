import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/features/sessions/session_avatar.dart';
import 'package:happy_flutter/features/sessions/widgets/session_cards.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── parseAvatarStyle ────────────────────────────────────

  group('parseAvatarStyle', () {
    test('returns gradient for "gradient"', () {
      expect(parseAvatarStyle('gradient'), AvatarStyle.gradient);
    });

    test('returns pixelated for "pixelated"', () {
      expect(parseAvatarStyle('pixelated'), AvatarStyle.pixelated);
    });

    test('returns brutalist for "brutalist"', () {
      expect(parseAvatarStyle('brutalist'), AvatarStyle.brutalist);
    });

    test('returns colorful generated styles', () {
      expect(parseAvatarStyle('neon'), AvatarStyle.neon);
      expect(parseAvatarStyle('bloom'), AvatarStyle.bloom);
      expect(parseAvatarStyle('prism'), AvatarStyle.prism);
    });

    test('returns null for unknown style', () {
      expect(parseAvatarStyle('unknown'), isNull);
    });

    test('returns null for null input', () {
      expect(parseAvatarStyle(null), isNull);
    });

    test('returns null for empty string', () {
      expect(parseAvatarStyle(''), isNull);
    });
  });

  // ─── getTodoProgress ─────────────────────────────────────

  group('getTodoProgress', () {
    test('returns null for null todos', () {
      expect(getTodoProgress(null), isNull);
    });

    test('returns null for empty todos', () {
      expect(getTodoProgress([]), isNull);
    });

    test('returns null when all todos completed', () {
      final todos = [
        _todo(status: TodoState.completed),
        _todo(status: TodoState.completed),
      ];
      expect(getTodoProgress(todos), isNull);
    });

    test('returns progress when some todos completed', () {
      final todos = [
        _todo(status: TodoState.completed),
        _todo(status: TodoState.pending),
        _todo(status: TodoState.inProgress),
      ];
      final result = getTodoProgress(todos);
      expect(result, isNotNull);
      expect(result!.completed, 1);
      expect(result.total, 3);
    });

    test('returns zero progress when none completed', () {
      final todos = [
        _todo(status: TodoState.pending),
        _todo(status: TodoState.inProgress),
      ];
      final result = getTodoProgress(todos);
      expect(result, isNotNull);
      expect(result!.completed, 0);
      expect(result.total, 2);
    });
  });

  // ─── ActiveSessionCard ──────────────────────────────────

  group('ActiveSessionCard', () {
    testWidgets('renders session name from path', (tester) async {
      final session = _session(
        id: 'test-1',
        path: '/home/user/myproject',
        presence: 'offline',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ActiveSessionCard(
              session: session,
              showFlavorIcon: true,
              onTap: () {},
            ),
          ),
        ),
      );

      // getSessionName uses last path segment
      expect(find.text('myproject'), findsOneWidget);
    });

    testWidgets('renders path as subtitle', (tester) async {
      final session = _session(
        id: 'test-2',
        path: '/home/user/testproject',
        host: 'myhost',
        presence: 'offline',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ActiveSessionCard(session: session, showFlavorIcon: true),
          ),
        ),
      );

      await tester.pump();
      // Subtitle shows the path
      expect(find.text('/home/user/testproject'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final session = _session(
        id: 'test-3',
        path: '/tapme',
        presence: 'offline',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ActiveSessionCard(
              session: session,
              showFlavorIcon: true,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('tapme'));
      expect(tapped, isTrue);
    });

    testWidgets('renders draft badge when draft exists', (tester) async {
      final session = _session(
        id: 'test-4',
        path: '/project',
        presence: 'offline',
        draft: 'Hello draft',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ActiveSessionCard(session: session, showFlavorIcon: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.drive_file_rename_outline), findsOneWidget);
    });

    testWidgets('does not render draft badge when no draft', (tester) async {
      final session = _session(
        id: 'test-5',
        path: '/nodraft',
        presence: 'offline',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ActiveSessionCard(session: session, showFlavorIcon: true),
          ),
        ),
      );

      expect(find.byIcon(Icons.drive_file_rename_outline), findsNothing);
    });
  });

  // ─── SessionCard ────────────────────────────────────────

  group('SessionCard', () {
    testWidgets('renders session name', (tester) async {
      final session = _session(
        id: 'inactive-1',
        path: '/home/oldproject',
        active: false,
        presence: 'offline',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SessionCard(
              session: session,
              showFlavorIcon: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('oldproject'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      final session = _session(
        id: 'inactive-2',
        path: '/tapme',
        active: false,
        presence: 'offline',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SessionCard(
              session: session,
              showFlavorIcon: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('tapme'));
      expect(tapped, isTrue);
    });

    testWidgets('shows TodoProgressBadge when todos exist', (tester) async {
      final session = _session(
        id: 'inactive-3',
        path: '/todos',
        active: false,
        presence: 'offline',
        todos: [
          _todo(status: TodoState.completed),
          _todo(status: TodoState.pending),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SessionCard(session: session, showFlavorIcon: false),
          ),
        ),
      );

      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('supports selection mode', (tester) async {
      final session = _session(
        id: 'sel-1',
        path: '/selectable',
        active: false,
        presence: 'offline',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SessionCard(
              session: session,
              showFlavorIcon: false,
              selectionMode: true,
              isSelected: true,
            ),
          ),
        ),
      );

      // Selection checkbox with check icon should appear
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  });
}

// ─── Test helpers ─────────────────────────────────────────

TodoItem _todo({required TodoState status}) {
  return TodoItem(
    id: 'todo-${status.name}',
    content: 'Task',
    status: status,
    priority: 'medium',
    order: 0,
    createdAt: 1,
    updatedAt: 1,
  );
}

Session _session({
  required String id,
  required String path,
  required String presence,
  String host = 'localhost',
  bool active = true,
  String? draft,
  List<TodoItem>? todos,
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
    thinking: false,
    presence: presence,
    draft: draft,
    todos: todos,
    metadata: Metadata(host: host, path: path),
  );
}
