import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/features/chat/widgets/inline_permission_visibility.dart';
import 'package:happy_flutter/features/chat/widgets/pending_permission_bar.dart';

/// A transcript with the inline approval card at the top and a sticky
/// [PendingPermissionBar] under it, like the chat screen.
Widget _harness({
  required ScrollController controller,
  required String sessionId,
  required Map<String, RequestInfo> requests,
  String cardId = 'p1',
  bool cardActive = true,
}) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  InlinePermissionVisibility(
                    permissionKey: inlinePermissionKey(sessionId, cardId),
                    active: cardActive,
                    child: const SizedBox(height: 120, child: Text('card')),
                  ),
                  const SizedBox(height: 3000),
                ],
              ),
            ),
            PendingPermissionBar(
              sessionId: sessionId,
              requests: requests,
              agentName: 'Claude',
            ),
          ],
        ),
      ),
    ),
  );
}

Map<String, RequestInfo> _request(String id) => {
  id: const RequestInfo(tool: 'Bash', arguments: {'command': 'git push'}),
};

void main() {
  setUp(() => visibleInlinePermissions.value = const <String>{});

  testWidgets('the bar stays hidden while the inline card is on screen', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _harness(
        controller: controller,
        sessionId: 's-a',
        requests: _request('p1'),
      ),
    );
    await tester.pump();

    expect(visibleInlinePermissions.value, contains('s-a/p1'));
    expect(find.text('Claude is waiting for your approval'), findsNothing);
    expect(find.text('Allow once'), findsNothing);
  });

  testWidgets('the bar returns once the card scrolls away, and leaves again', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _harness(
        controller: controller,
        sessionId: 's-b',
        requests: _request('p1'),
      ),
    );
    await tester.pump();
    expect(find.text('Allow once'), findsNothing);

    controller.jumpTo(1500);
    await tester.pump();
    await tester.pump();
    expect(visibleInlinePermissions.value, isNot(contains('s-b/p1')));
    expect(find.text('Claude is waiting for your approval'), findsOneWidget);
    expect(find.text('Allow once'), findsOneWidget);

    controller.jumpTo(0);
    await tester.pump();
    await tester.pump();
    expect(find.text('Allow once'), findsNothing);
  });

  testWidgets('a request without a visible card keeps the bar', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    // The card on screen belongs to another request.
    await tester.pumpWidget(
      _harness(
        controller: controller,
        sessionId: 's-c',
        requests: _request('p2'),
        cardId: 'p1',
      ),
    );
    await tester.pump();
    expect(find.text('Allow once'), findsOneWidget);
  });

  testWidgets('an answered card never hides the bar', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _harness(
        controller: controller,
        sessionId: 's-d',
        requests: _request('p1'),
        cardActive: false,
      ),
    );
    await tester.pump();
    expect(visibleInlinePermissions.value, isNot(contains('s-d/p1')));
    expect(find.text('Allow once'), findsOneWidget);
  });

  testWidgets('disposing the card releases its key', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _harness(
        controller: controller,
        sessionId: 's-e',
        requests: _request('p1'),
      ),
    );
    await tester.pump();
    expect(visibleInlinePermissions.value, contains('s-e/p1'));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(visibleInlinePermissions.value, isNot(contains('s-e/p1')));
  });
}
