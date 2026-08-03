import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/widgets/task_event_summary_card.dart';

Widget _app(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('TaskEventSummaryCard', () {
    testWidgets('renders completed task with summary', (tester) async {
      await tester.pumpWidget(
        _app(
          TaskEventSummaryCard(
            data: const <String, dynamic>{
              'taskEvent': true,
              'taskStatus': 'completed',
              'taskType': 'local_workflow',
              'content': 'All branches reconciled.',
            },
          ),
        ),
      );

      expect(find.text('Task completed'), findsOneWidget);
      expect(find.text('All branches reconciled.'), findsOneWidget);
    });

    testWidgets('renders failed task without summary', (tester) async {
      await tester.pumpWidget(
        _app(
          TaskEventSummaryCard(
            data: const <String, dynamic>{
              'taskEvent': true,
              'taskStatus': 'failed',
              'taskType': 'local_bash',
              'content': '',
            },
          ),
        ),
      );

      expect(find.text('Task failed'), findsOneWidget);
    });

    testWidgets('falls back to status label when no content', (tester) async {
      await tester.pumpWidget(
        _app(
          TaskEventSummaryCard(
            data: const <String, dynamic>{
              'taskEvent': true,
              'taskStatus': 'running',
              'taskType': 'general-purpose',
            },
          ),
        ),
      );

      expect(find.text('Task updated'), findsOneWidget);
    });

    testWidgets('shows transcript path and copies it on tap', (tester) async {
      String? clipboardText;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (
        MethodCall call,
      ) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<Object?, Object?>;
          clipboardText = args['text']! as String;
        }
        return null;
      });

      const path = '/Users/me/.claude/projects/foo/transcripts/x.jsonl';
      await tester.pumpWidget(
        _app(
          TaskEventSummaryCard(
            data: const <String, dynamic>{
              'taskEvent': true,
              'taskStatus': 'completed',
              'taskType': 'local_workflow',
              'content': 'Done',
              'transcriptDir': path,
              'workflowRunId': 'run-abc',
            },
          ),
        ),
      );

      expect(find.text(path), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(clipboardText, path);
      expect(find.text('Copied transcript path: $path'), findsOneWidget);
    });

    testWidgets('shows run id when transcript dir is absent', (tester) async {
      await tester.pumpWidget(
        _app(
          TaskEventSummaryCard(
            data: const <String, dynamic>{
              'taskEvent': true,
              'taskStatus': 'completed',
              'workflowRunId': 'run-xyz',
            },
          ),
        ),
      );

      expect(find.text('run: run-xyz'), findsOneWidget);
    });
  });
}
