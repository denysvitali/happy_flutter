import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/rpc/rpc_types.dart';
import 'package:happy_flutter/features/chat/session_file_viewer_screen.dart';

/// 1x1 transparent PNG, base64-encoded — the wire shape the daemon
/// returns from machineReadFile.
const String kTinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

class _Sessions extends SessionsNotifier {
  @override
  Map<String, Session> build() => {
    's1': const Session(
      id: 's1',
      seq: 0,
      createdAt: 0,
      updatedAt: 0,
      active: false,
      activeAt: 0,
      metadataVersion: 0,
      agentStateVersion: 0,
      thinking: false,
      metadata: Metadata(machineId: 'm1'),
    ),
  };
}

class _Machines extends MachinesNotifier {
  final pending = Completer<ReadFileResponse>();

  @override
  Future<ReadFileResponse> readFile({
    required String machineId,
    required String filePath,
  }) => pending.future;
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  testWidgets('changing files resets code scroll while refresh preserves it', (
    tester,
  ) async {
    final content = List.generate(
      100,
      (index) => 'line $index ${'x' * 200}',
    ).join('\n');
    Widget viewer(String path, String text) => _wrap(
      SessionFileViewerScreen(path: path, sessionId: 's1', content: text),
    );
    ScrollController controller(Axis axis) => tester
        .widget<SingleChildScrollView>(
          find.byWidgetPredicate(
            (widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == axis,
          ),
        )
        .controller!;

    await tester.pumpWidget(viewer('/tmp/first.txt', content));
    controller(Axis.vertical).jumpTo(100);
    controller(Axis.horizontal).jumpTo(100);
    await tester.pumpWidget(viewer('/tmp/first.txt', '$content\nMore text'));
    expect(controller(Axis.vertical).offset, 100);
    expect(controller(Axis.horizontal).offset, 100);

    await tester.pumpWidget(viewer('/tmp/second.txt', content));
    expect(controller(Axis.vertical).offset, 0);
    expect(controller(Axis.horizontal).offset, 0);
  });

  testWidgets('late clipboard completion does not mark another file copied', (
    tester,
  ) async {
    final copied = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') await copied.future;
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    Widget viewer(String path) => _wrap(
      SessionFileViewerScreen(path: path, sessionId: 's1', content: path),
    );

    await tester.pumpWidget(viewer('/tmp/first.txt'));
    await tester.tap(find.byTooltip('Copy file'));
    await tester.pumpWidget(viewer('/tmp/second.txt'));
    copied.complete();
    await tester.pump();
    expect(find.byTooltip('Copied!'), findsNothing);
    expect(find.byTooltip('Copy file'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('clipboard failures do not report a successful copy', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'clipboard-unavailable');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      _wrap(
        const SessionFileViewerScreen(
          path: '/tmp/file.txt',
          sessionId: 's1',
          content: 'contents',
        ),
      ),
    );
    await tester.tap(find.byTooltip('Copy file'));
    await tester.pump();
    expect(find.byTooltip('Copied!'), findsNothing);
    expect(find.text('Could not copy file'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final fails in [false, true]) {
    testWidgets('ignores a stale file fetch (fails: $fails)', (tester) async {
      final machines = _Machines();
      final container = ProviderContainer(
        overrides: [
          sessionsNotifierProvider.overrideWith(_Sessions.new),
          machinesNotifierProvider.overrideWith(() => machines),
        ],
      );
      addTearDown(container.dispose);
      Widget viewer(String? content) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SessionFileViewerScreen(
            path: '/tmp/file.txt',
            sessionId: 's1',
            content: content,
          ),
        ),
      );

      await tester.pumpWidget(viewer(null));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(viewer('new contents'));
      if (fails) {
        machines.pending.completeError(StateError('stale failure'));
      } else {
        machines.pending.complete(
          const ReadFileResponse(success: true, content: 'old contents'),
        );
      }
      await tester.pump();

      expect(
        find.textContaining('new contents', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Could not load file'), findsNothing);
      expect(
        find.textContaining('old contents', findRichText: true),
        findsNothing,
      );
    });
  }

  testWidgets('supplied empty content does not require a remote machine', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SessionFileViewerScreen(
          path: '/tmp/empty.txt',
          sessionId: 's1',
          content: '',
        ),
      ),
    );

    expect(find.text('No content'), findsOneWidget);
    expect(find.text('Could not load file'), findsNothing);
  });

  testWidgets('refreshes supplied content when the file pane is reused', (
    tester,
  ) async {
    Widget viewer(String content) => _wrap(
      SessionFileViewerScreen(
        path: '/src/main.dart',
        sessionId: 's1',
        content: content,
      ),
    );

    await tester.pumpWidget(viewer('old contents'));
    await tester.pumpWidget(viewer('new contents'));

    expect(
      find.textContaining('new contents', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('old contents', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('code and line numbers share one vertical scroll position', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SessionFileViewerScreen(
          path: '/tmp/long.txt',
          sessionId: 's1',
          content: List.generate(100, (index) => 'line $index').join('\n'),
        ),
      ),
    );

    final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(scrollbar.controller!.positions, hasLength(1));
    await tester.drag(find.byType(Scrollbar), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(scrollbar.controller!.offset, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders PNG content as an image, not text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SessionFileViewerScreen(
          path: '/tmp/screenshot.png',
          sessionId: 's1',
          content: kTinyPngBase64,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    // The raw base64 payload must not appear as text.
    expect(find.textContaining('iVBOR'), findsNothing);
  });

  testWidgets('jpeg extension also renders as image', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SessionFileViewerScreen(
          path: '/photos/pic.JPEG',
          sessionId: 's1',
          content: kTinyPngBase64,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('text file stays a code view', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SessionFileViewerScreen(
          path: '/src/main.dart',
          sessionId: 's1',
          content: 'hello world\nline two',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsNothing);
  });

  testWidgets('image file with non-base64 content falls back to text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const SessionFileViewerScreen(
          path: '/tmp/broken.png',
          sessionId: 's1',
          content: 'not base64 at all!!!',
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(
      find.textContaining('not base64 at all', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('copy button hidden for image files', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SessionFileViewerScreen(
          path: '/tmp/screenshot.png',
          sessionId: 's1',
          content: kTinyPngBase64,
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.content_copy_rounded), findsNothing);
  });
}
