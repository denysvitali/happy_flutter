import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/features/chat/tools/views/ask_user_question_view.dart';

class _RecordingPermissionsNotifier extends PermissionsNotifier {
  final List<Map<String, dynamic>> allowCalls = [];

  @override
  Future<PermissionResponse> allow(
    String sessionId,
    String permissionId, {
    String? mode,
    List<String>? allowTools,
    String? decision,
    Map<String, dynamic>? updatedInput,
  }) async {
    allowCalls.add(<String, dynamic>{
      'sessionId': sessionId,
      'permissionId': permissionId,
      'updatedInput': updatedInput,
    });
    return const PermissionResponse(success: true);
  }
}

Widget _wrap(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

Map<String, dynamic> _tool({bool multiSelect = false}) => <String, dynamic>{
  'name': 'AskUserQuestion',
  'toolUseId': 'call-1',
  'input': <String, dynamic>{
    'questions': <Map<String, dynamic>>[
      <String, dynamic>{
        'question': 'Which database?',
        'header': 'Database',
        'multiSelect': multiSelect,
        'options': <Map<String, dynamic>>[
          <String, dynamic>{'label': 'Postgres', 'description': 'Relational'},
          <String, dynamic>{'label': 'SQLite', 'description': 'Embedded'},
        ],
      },
    ],
  },
  'permission': <String, dynamic>{'id': 'perm-1', 'status': 'pending'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders questions, options, and a notes field', (tester) async {
    final container = ProviderContainer(
      overrides: [
        permissionsNotifierProvider.overrideWith(
          _RecordingPermissionsNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(container, AskUserQuestionView(tool: _tool(), sessionId: 's1')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Which database?'), findsOneWidget);
    expect(find.text('Postgres'), findsOneWidget);
    expect(find.text('SQLite'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('tapping an answer plus notes submits answers and annotations', (
    tester,
  ) async {
    final notifier = _RecordingPermissionsNotifier();
    final container = ProviderContainer(
      overrides: [permissionsNotifierProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(container, AskUserQuestionView(tool: _tool(), sessionId: 's1')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Postgres'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Use read replicas');
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump();

    expect(notifier.allowCalls, hasLength(1));
    final call = notifier.allowCalls.single;
    expect(call['sessionId'], 's1');
    expect(call['permissionId'], 'perm-1');
    final updatedInput = call['updatedInput'] as Map<String, dynamic>;
    expect(updatedInput['answers'], <String, String>{
      'Which database?': 'Postgres',
    });
    expect(updatedInput['annotations'], <String, dynamic>{
      'Which database?': <String, String>{'notes': 'Use read replicas'},
    });

    // Interactive view is replaced by the read-only "Answered" summary.
    expect(find.text('Answered'), findsOneWidget);
    expect(find.text('Notes: Use read replicas'), findsOneWidget);
  });

  testWidgets('submit is ignored until a question is answered', (tester) async {
    final notifier = _RecordingPermissionsNotifier();
    final container = ProviderContainer(
      overrides: [permissionsNotifierProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(container, AskUserQuestionView(tool: _tool(), sessionId: 's1')),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Submit'));
    await tester.pump();

    expect(notifier.allowCalls, isEmpty);
    expect(find.text('Answered'), findsNothing);
  });

  testWidgets('multi-select joins selected labels with a comma', (
    tester,
  ) async {
    final notifier = _RecordingPermissionsNotifier();
    final container = ProviderContainer(
      overrides: [permissionsNotifierProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(
        container,
        AskUserQuestionView(tool: _tool(multiSelect: true), sessionId: 's1'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Postgres'));
    await tester.pump();
    await tester.tap(find.text('SQLite'));
    await tester.pump();

    await tester.tap(find.text('Submit'));
    await tester.pump();
    await tester.pump();

    final call = notifier.allowCalls.single;
    final updatedInput = call['updatedInput'] as Map<String, dynamic>;
    expect(updatedInput['answers'], <String, String>{
      'Which database?': 'Postgres, SQLite',
    });
  });

  testWidgets('empty questions renders nothing without crashing', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        permissionsNotifierProvider.overrideWith(
          _RecordingPermissionsNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _wrap(
        container,
        AskUserQuestionView(
          tool: <String, dynamic>{
            'name': 'AskUserQuestion',
            'input': <String, dynamic>{'questions': <dynamic>[]},
            'permission': <String, dynamic>{
              'id': 'perm-1',
              'status': 'pending',
            },
          },
          sessionId: 's1',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AskUserQuestionView), findsOneWidget);
    expect(find.text('Input needed'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
