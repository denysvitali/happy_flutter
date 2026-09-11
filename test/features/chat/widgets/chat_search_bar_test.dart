import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/chat_search_bar.dart';

/// In-conversation search bar: the counter, the disabled state of the
/// navigation arrows and the wiring of every callback. The chat screen owns
/// the query and the match list, so the bar must stay dumb and honest about
/// "no matches" versus "still searching older messages".

// Delegates go on MaterialApp: its inner LocalizationsScope wins the lookup.
Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(appBar: AppBar(title: child)),
);

void main() {
  testWidgets('empty query shows the hint and no counter', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        ChatSearchBar(
          controller: controller,
          matchCount: 0,
          currentIndex: -1,
          onChanged: (_) {},
          onPrevious: () {},
          onNext: () {},
          onClose: () {},
        ),
      ),
    );

    expect(find.text('Search in conversation'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-search-counter')),
      findsNothing,
    );
  });

  testWidgets('counter reports the selected match position', (tester) async {
    final controller = TextEditingController(text: 'needle');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        ChatSearchBar(
          controller: controller,
          matchCount: 12,
          currentIndex: 2,
          onChanged: (_) {},
          onPrevious: () {},
          onNext: () {},
          onClose: () {},
        ),
      ),
    );

    expect(find.text('3 of 12'), findsOneWidget);
  });

  testWidgets('a query with no hits says so instead of showing 0 of 0', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'needle');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        ChatSearchBar(
          controller: controller,
          matchCount: 0,
          currentIndex: -1,
          onChanged: (_) {},
          onPrevious: () {},
          onNext: () {},
          onClose: () {},
        ),
      ),
    );

    expect(find.text('No matches in loaded messages'), findsOneWidget);
  });

  testWidgets('paging older messages shows an ellipsis, not a false zero', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'needle');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        ChatSearchBar(
          controller: controller,
          matchCount: 0,
          currentIndex: -1,
          isSearchingOlderMessages: true,
          onChanged: (_) {},
          onPrevious: () {},
          onNext: () {},
          onClose: () {},
        ),
      ),
    );

    expect(find.text('…'), findsOneWidget);
    expect(find.text('No matches in loaded messages'), findsNothing);
  });

  testWidgets('navigation is disabled without matches and wired with them', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'needle');
    addTearDown(controller.dispose);
    var previous = 0;
    var next = 0;

    Widget build({required int matchCount}) => _host(
      ChatSearchBar(
        controller: controller,
        matchCount: matchCount,
        currentIndex: matchCount > 0 ? 0 : -1,
        onChanged: (_) {},
        onPrevious: () => previous++,
        onNext: () => next++,
        onClose: () {},
      ),
    );

    await tester.pumpWidget(build(matchCount: 0));
    await tester.tap(find.byKey(const ValueKey('chat-search-previous')));
    await tester.tap(find.byKey(const ValueKey('chat-search-next')));
    await tester.pump();
    expect(previous, 0);
    expect(next, 0);

    await tester.pumpWidget(build(matchCount: 2));
    await tester.tap(find.byKey(const ValueKey('chat-search-previous')));
    await tester.tap(find.byKey(const ValueKey('chat-search-next')));
    await tester.pump();
    expect(previous, 1);
    expect(next, 1);
  });

  testWidgets('typing and closing reach their callbacks', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final typed = <String>[];
    var closed = 0;

    await tester.pumpWidget(
      _host(
        ChatSearchBar(
          controller: controller,
          matchCount: 0,
          currentIndex: -1,
          onChanged: typed.add,
          onPrevious: () {},
          onNext: () {},
          onClose: () => closed++,
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('chat-search-field')),
      'exfat',
    );
    await tester.pump();
    expect(typed.last, 'exfat');

    await tester.tap(find.byKey(const ValueKey('chat-search-close')));
    await tester.pump();
    expect(closed, 1);
  });
}
