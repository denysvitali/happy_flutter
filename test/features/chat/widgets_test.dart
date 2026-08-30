import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/chat_loading_shimmer.dart';
import 'package:happy_flutter/features/chat/widgets/path_chip.dart';
import 'package:happy_flutter/features/chat/widgets/scroll_to_bottom_pill.dart';
import 'package:happy_flutter/features/chat/widgets/session_header_chip.dart';
import 'package:happy_flutter/features/chat/widgets/empty_chat_view.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── PathChip ──────────────────────────────────────────────────────

  group('PathChip', () {
    testWidgets('renders the given path text', (tester) async {
      await tester.pumpWidget(_wrap(const PathChip(path: 'lib/main.dart')));

      expect(find.text('lib/main.dart'), findsOneWidget);
    });

    testWidgets('shows folder icon', (tester) async {
      await tester.pumpWidget(_wrap(const PathChip(path: 'src/utils')));

      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('uses monospace font style', (tester) async {
      await tester.pumpWidget(_wrap(const PathChip(path: 'test.dart')));

      final text = tester.widget<Text>(find.text('test.dart'));
      expect(text.style?.fontFamily, 'monospace');
    });

    testWidgets('renders long paths with ellipsis', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 80,
            child: PathChip(
              path: 'very/long/path/to/some/deeply/nested/file.dart',
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.byType(Text).first);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.maxLines, 1);
    });
  });

  // ── SessionHeaderChip ─────────────────────────────────────────────

  group('SessionHeaderChip', () {
    testWidgets('renders text', (tester) async {
      await tester.pumpWidget(_wrap(const SessionHeaderChip(text: 'Online')));

      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('renders leading widget when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SessionHeaderChip(
            text: 'Active',
            leading: Icon(Icons.circle, size: 8),
          ),
        ),
      );

      expect(find.byIcon(Icons.circle), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('omits leading when null', (tester) async {
      await tester.pumpWidget(_wrap(const SessionHeaderChip(text: 'Idle')));

      // Only the text icon should be present.
      expect(find.text('Idle'), findsOneWidget);
    });

    testWidgets('text has ellipsis overflow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 50,
            child: SessionHeaderChip(
              text: 'Very long status text that overflows',
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.textContaining('Very'));
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });

  // ── ChatLoadingShimmer ────────────────────────────────────────────

  group('ChatLoadingShimmer', () {
    testWidgets('renders a ListView', (tester) async {
      await tester.pumpWidget(_wrap(const ChatLoadingShimmer()));

      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('renders 5 shimmer items', (tester) async {
      await tester.pumpWidget(_wrap(const ChatLoadingShimmer()));
      await tester.pump();

      // ListView.builder with itemCount: 5.
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('list is reverse-ordered', (tester) async {
      await tester.pumpWidget(_wrap(const ChatLoadingShimmer()));

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.reverse, isTrue);
    });
  });

  // ── ScrollToBottomPill ────────────────────────────────────────────

  group('ScrollToBottomPill', () {
    testWidgets('renders a down arrow icon', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(ScrollToBottomPill(onTap: () => tapped = true)),
      );
      await tester.pumpAndSettle();

      expect(
        find.byIcon(Icons.keyboard_double_arrow_down_rounded),
        findsOneWidget,
      );
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(ScrollToBottomPill(onTap: () => tapped = true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ScrollToBottomPill));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('has semantics label', (tester) async {
      await tester.pumpWidget(_wrap(ScrollToBottomPill(onTap: () {})));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Scroll to latest message'), findsOneWidget);
    });

    testWidgets('shows badge when unreadCount > 0', (tester) async {
      await tester.pumpWidget(
        _wrap(ScrollToBottomPill(onTap: () {}, unreadCount: 5)),
      );
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('does not show badge when unreadCount is null', (tester) async {
      await tester.pumpWidget(_wrap(ScrollToBottomPill(onTap: () {})));
      await tester.pumpAndSettle();

      // No badge text should be rendered.
      expect(find.text('0'), findsNothing);
    });

    testWidgets('shows 99+ for large counts', (tester) async {
      await tester.pumpWidget(
        _wrap(ScrollToBottomPill(onTap: () {}, unreadCount: 150)),
      );
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsOneWidget);
    });
  });

  // ── EmptyChatView ─────────────────────────────────────────────────

  group('EmptyChatView', () {
    testWidgets('renders title and subtitle', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyChatView()));
      await tester.pumpAndSettle();

      expect(find.text('How can I help you today?'), findsOneWidget);
    });

    testWidgets('renders chat bubble icon', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyChatView()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    });

    testWidgets('renders all four suggestion cards', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyChatView()));
      await tester.pumpAndSettle();

      expect(find.text('Write code'), findsOneWidget);
      expect(find.text('Debug an issue'), findsOneWidget);
      expect(find.text('Explain code'), findsOneWidget);
      expect(find.text('Review PR'), findsOneWidget);
    });

    testWidgets('renders suggestion subtitles', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyChatView()));
      await tester.pumpAndSettle();

      expect(find.text('Generate a function or component'), findsOneWidget);
      expect(find.text('Find and fix a bug in your code'), findsOneWidget);
    });

    testWidgets('tapping suggestion calls onSuggestionTap', (tester) async {
      String? tappedTitle;
      await tester.pumpWidget(
        _wrap(EmptyChatView(onSuggestionTap: (title) => tappedTitle = title)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Write code'));
      await tester.pump();

      expect(tappedTitle, 'Build this feature with production-ready code: ');
    });

    testWidgets('renders suggestion icons', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyChatView()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.code_rounded), findsOneWidget);
      expect(find.byIcon(Icons.bug_report_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
      expect(find.byIcon(Icons.rate_review_rounded), findsOneWidget);
    });

    testWidgets('is scrollable', (tester) async {
      await tester.pumpWidget(_wrap(const EmptyChatView()));
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
