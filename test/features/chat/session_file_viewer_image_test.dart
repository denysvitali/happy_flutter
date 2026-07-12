import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/session_file_viewer_screen.dart';

/// 1x1 transparent PNG, base64-encoded — the wire shape the daemon
/// returns from machineReadFile.
const String kTinyPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(home: child),
  );
}

void main() {
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
