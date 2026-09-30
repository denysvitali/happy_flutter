import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/desktop_chat_workspace.dart';

const _conversation = Key('conversation');
const _inspector = Key('inspector');

Widget _harness({
  bool hideTools = false,
  bool inspector = false,
  Widget? content,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: DesktopChatWorkspace(
        mobileHideToolCalls: hideTools,
        inspector: inspector ? const SizedBox(key: _inspector) : null,
        builder: (collapseTools) =>
            content ??
            Column(
              key: _conversation,
              children: [
                Text(collapseTools ? 'grouped' : 'full trace'),
                const TextField(),
                const Expanded(child: SizedBox()),
              ],
            ),
      ),
    ),
  );
}

class _ConversationFixture extends StatefulWidget {
  const _ConversationFixture();

  @override
  State<_ConversationFixture> createState() => _ConversationFixtureState();
}

class _ConversationFixtureState extends State<_ConversationFixture> {
  final _scrollController = ScrollController();
  bool _expanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TextField(),
        TextButton(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: const Text('Expand tool details'),
        ),
        if (_expanded) const Text('Tool details'),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            itemExtent: 40,
            itemCount: 100,
            itemBuilder: (_, index) => Text('Message $index'),
          ),
        ),
      ],
    );
  }
}

void main() {
  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('phone preserves both existing tool preferences', (tester) async {
    viewport(tester, 390);
    await tester.pumpWidget(_harness());
    expect(find.text('full trace'), findsOneWidget);
    expect(find.text('Show all tool calls'), findsNothing);
    expect(tester.getSize(find.byKey(_conversation)).width, 390);
    await tester.pumpWidget(_harness(hideTools: true));
    expect(find.text('grouped'), findsOneWidget);
  });

  testWidgets('desktop toggle preserves draft and does not change mobile', (
    tester,
  ) async {
    viewport(tester, 1200);
    await tester.pumpWidget(_harness());
    expect(find.text('grouped'), findsOneWidget);
    expect(tester.getSize(find.byKey(_conversation)).width, 880);
    await tester.enterText(find.byType(TextField), 'unsent draft');
    await tester.tap(find.text('Show all tool calls'));
    await tester.pump();
    expect(find.text('full trace'), findsOneWidget);
    expect(find.text('unsent draft'), findsOneWidget);
    await tester.tap(find.text('Hide Tool Calls'));
    await tester.pump();
    expect(find.text('grouped'), findsOneWidget);
    tester.view.physicalSize = const Size(390, 800);
    await tester.pump();
    expect(find.text('full trace'), findsOneWidget);
    expect(find.text('Show all tool calls'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inspector takes space only while selected', (tester) async {
    viewport(tester, 1200);
    await tester.pumpWidget(_harness(inspector: true));
    expect(tester.getSize(find.byKey(_inspector)).width, greaterThan(450));
    expect(tester.getSize(find.byKey(_conversation)).width, greaterThan(700));
    await tester.pumpWidget(_harness());
    expect(find.byKey(_inspector), findsNothing);
    expect(tester.getSize(find.byKey(_conversation)).width, 880);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inspector preserves draft, focus, scroll and expanded tools', (
    tester,
  ) async {
    viewport(tester, 1200);
    await tester.pumpWidget(_harness(content: const _ConversationFixture()));
    await tester.tap(find.text('Expand tool details'));
    await tester.enterText(find.byType(TextField), 'Draft under review');
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pump(const Duration(seconds: 1));
    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    final offset = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(offset, greaterThan(0));

    for (final inspector in [true, false, true, false]) {
      await tester.pumpWidget(
        _harness(inspector: inspector, content: const _ConversationFixture()),
      );
      expect(find.text('Draft under review'), findsOneWidget);
      expect(find.text('Tool details'), findsOneWidget);
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(
        tester.state<ScrollableState>(scrollable).position.pixels,
        closeTo(offset, 0.1),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
