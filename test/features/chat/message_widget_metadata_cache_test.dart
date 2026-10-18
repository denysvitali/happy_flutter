// Pins `MessageWidget`'s memoized body against the session metadata it
// renders with.
//
// The body cache short-circuits on an O(1) config hash plus row-map
// identity. Session metadata is a render input (tool subtitles resolve
// file paths against `metadata['path']`, the header reads
// `metadata['flavor']`), so a metadata change with an unchanged row map
// must repaint. Otherwise a chat that opened before its session metadata
// hydrated keeps rendering absolute paths for the rest of the visit.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/message_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One shared row map across both pumps: the production chat list hands
  // the same instance back until the message itself changes.
  final tool = <String, dynamic>{
    'id': 'm1',
    'kind': 'tool-call',
    'name': 'Read',
    'state': 'completed',
    'input': <String, dynamic>{'file_path': '/home/dev/proj/lib/a.dart'},
  };

  // The metadata swap must not remount the row: only then does the body
  // cache get a chance to serve the stale subtree.
  final metadata = ValueNotifier<Map<String, dynamic>?>(null);

  Widget wrap() {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<Map<String, dynamic>?>(
                valueListenable: metadata,
                builder: (context, value, _) => MessageWidget(
                  messageData: tool,
                  metadata: value,
                  isFromCurrentUser: false,
                  sessionId: 's1',
                  animate: false,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('tool subtitle follows late session metadata', (tester) async {
    addTearDown(metadata.dispose);
    await tester.pumpWidget(wrap());
    await settle(tester);
    expect(
      find.textContaining('/home/dev/proj/lib/a.dart', findRichText: true),
      findsWidgets,
    );

    metadata.value = const <String, dynamic>{'path': '/home/dev/proj'};
    await settle(tester);

    expect(
      find.textContaining('lib/a.dart', findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining('/home/dev/proj/lib/a.dart', findRichText: true),
      findsNothing,
      reason: 'session metadata is a render input of the memoized body',
    );
  });
}
