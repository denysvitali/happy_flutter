import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/ui/shimmer/shimmer.dart';
import 'package:happy_flutter/core/ui/shimmer/skeleton_list.dart';

/// Hands [child] loose constraints inside a fixed-width column so the
/// skeletons' own sizing (not the harness) decides the measured geometry.
Widget _app(Widget child, {double width = 400}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: Align(alignment: Alignment.topCenter, child: child),
      ),
    ),
  ),
);

int _tickers(WidgetTester tester) => tester.binding.transientCallbackCount;

Finder _barsOf(Type skeleton) => find.descendant(
  of: find.byType(skeleton),
  matching: find.byType(Container),
);

void main() {
  group('SkeletonListTile', () {
    testWidgets('renders avatar, two text bars and a trailing bar', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const SkeletonListTile()));

      expect(_barsOf(SkeletonListTile), findsNWidgets(4));
      expect(find.byType(FractionallySizedBox), findsNWidgets(2));
    });

    testWidgets('honours the requested height and avatar size', (tester) async {
      await tester.pumpWidget(
        _app(const SkeletonListTile(avatarSize: 48, height: 72)),
      );

      final tile = find.descendant(
        of: find.byType(SkeletonListTile),
        matching: find.byType(SizedBox),
      );
      expect(tester.getSize(tile.first).height, 72);
      expect(
        tester.getSize(_barsOf(SkeletonListTile).first),
        const Size(48, 48),
      );
    });

    testWidgets('lays out on the narrowest supported phone width', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const SkeletonListTile(), width: 320));

      expect(tester.takeException(), isNull);
    });
  });

  group('SkeletonCard', () {
    testWidgets('takes the requested height and stretches by default', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const SkeletonCard(height: 96)));

      final size = tester.getSize(_barsOf(SkeletonCard).first);
      expect(size.height, 96);
      expect(size.width, 400);
    });

    testWidgets('a fixed width is respected', (tester) async {
      await tester.pumpWidget(_app(const SkeletonCard(height: 40, width: 120)));

      expect(tester.getSize(_barsOf(SkeletonCard).first).width, 120);
    });
  });

  group('SkeletonChatBubble', () {
    testWidgets('renders one bar per line', (tester) async {
      await tester.pumpWidget(_app(const SkeletonChatBubble(lineCount: 4)));

      expect(_barsOf(SkeletonChatBubble), findsNWidgets(4));
    });

    testWidgets('clamps the line count to at least one', (tester) async {
      await tester.pumpWidget(_app(const SkeletonChatBubble(lineCount: 0)));

      expect(_barsOf(SkeletonChatBubble), findsOneWidget);
    });

    testWidgets('clamps the line count to at most six', (tester) async {
      await tester.pumpWidget(_app(const SkeletonChatBubble(lineCount: 99)));

      expect(_barsOf(SkeletonChatBubble), findsNWidgets(6));
    });

    testWidgets('user bubbles align right, assistant bubbles left', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const SkeletonChatBubble(isUser: true)));
      final userLeft = tester.getTopLeft(_barsOf(SkeletonChatBubble).first).dx;

      await tester.pumpWidget(_app(const SkeletonChatBubble()));
      final agentLeft = tester.getTopLeft(_barsOf(SkeletonChatBubble).first).dx;

      expect(userLeft, greaterThan(agentLeft));
    });

    testWidgets('the widest line follows the bubble width fraction', (
      tester,
    ) async {
      const available = 400 - 2 * AppSpacing.md;

      await tester.pumpWidget(_app(const SkeletonChatBubble(isUser: true)));
      expect(
        tester.getSize(_barsOf(SkeletonChatBubble).first).width,
        closeTo(available * 0.72, 0.5),
      );

      await tester.pumpWidget(_app(const SkeletonChatBubble()));
      expect(
        tester.getSize(_barsOf(SkeletonChatBubble).first).width,
        closeTo(available * 0.88, 0.5),
      );
    });

    testWidgets('an explicit maxWidthFraction overrides the default', (
      tester,
    ) async {
      const available = 400 - 2 * AppSpacing.md;
      await tester.pumpWidget(
        _app(const SkeletonChatBubble(maxWidthFraction: 0.5)),
      );

      expect(
        tester.getSize(_barsOf(SkeletonChatBubble).first).width,
        closeTo(available * 0.5, 0.5),
      );
    });

    testWidgets('the tail line is shorter than the first', (tester) async {
      await tester.pumpWidget(_app(const SkeletonChatBubble(lineCount: 3)));

      final bars = _barsOf(SkeletonChatBubble);
      expect(
        tester.getSize(bars.at(2)).width,
        lessThan(tester.getSize(bars.at(0)).width),
      );
    });
  });

  group('SkeletonFormSection', () {
    testWidgets('renders a label bar plus one bar per field', (tester) async {
      await tester.pumpWidget(_app(const SkeletonFormSection(fieldCount: 3)));

      expect(_barsOf(SkeletonFormSection), findsNWidgets(4));
    });

    testWidgets('zero fields still renders the label', (tester) async {
      await tester.pumpWidget(_app(const SkeletonFormSection(fieldCount: 0)));

      expect(_barsOf(SkeletonFormSection), findsOneWidget);
    });

    testWidgets('the field height is configurable', (tester) async {
      await tester.pumpWidget(
        _app(const SkeletonFormSection(fieldCount: 1, fieldHeight: 24)),
      );

      expect(tester.getSize(_barsOf(SkeletonFormSection).at(1)).height, 24);
    });
  });

  group('SkeletonTwoColumn', () {
    testWidgets('renders exactly itemCount cards for an even count', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const SkeletonTwoColumn(itemCount: 4)));

      expect(find.byType(SkeletonCard), findsNWidgets(4));
    });

    testWidgets('renders exactly itemCount cards for an odd count', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SkeletonTwoColumn(itemCount: 5, itemHeight: 40)),
        ),
      );

      expect(find.byType(SkeletonCard), findsNWidgets(5));
    });

    testWidgets('an empty grid renders nothing', (tester) async {
      await tester.pumpWidget(_app(const SkeletonTwoColumn(itemCount: 0)));

      expect(find.byType(SkeletonCard), findsNothing);
    });

    testWidgets('the odd trailing slot keeps the column width', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SkeletonTwoColumn(itemCount: 3, itemHeight: 40)),
        ),
      );

      final cards = find.byType(SkeletonCard);
      expect(
        tester.getSize(cards.at(2)).width,
        closeTo(tester.getSize(cards.at(0)).width, 0.5),
      );
    });
  });

  group('SkeletonAvatarList', () {
    testWidgets('renders one tile per item under a single shared ticker', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const SkeletonAvatarList(itemCount: 6)));

      expect(find.byType(SkeletonListTile), findsNWidgets(6));
      expect(find.byType(ShimmerScope), findsOneWidget);
      expect(_tickers(tester), 1);
    });

    testWidgets('unmounting leaves no running ticker', (tester) async {
      await tester.pumpWidget(_app(const SkeletonAvatarList()));
      await tester.pumpWidget(_app(const SizedBox.shrink()));

      expect(_tickers(tester), 0);
      expect(tester.takeException(), isNull);
    });
  });
}
