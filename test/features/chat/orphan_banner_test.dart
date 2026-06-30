import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/app_color_scheme.dart';
import 'package:happy_flutter/features/chat/widgets/orphan_banner.dart';

/// Widget tests for the [OrphanBanner].
///
/// The banner is rendered as the FIRST item in the chat message list
/// whenever orphan sidechain messages exist in the loaded window.
/// Tapping the banner raises the chat's `_visibleCount` so the orphans
/// become visible (see chat_screen.dart and `_chat_screen_builders.dart`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ──────────────────────────────────────────────────────────────────
  // Test 1: orphan banner is hidden when orphanCount <= 0.
  // ──────────────────────────────────────────────────────────────────
  testWidgets(
    'OrphanBanner renders nothing when orphanCount is 0',
    (tester) async {
      await tester.pumpWidget(_wrapWithBanner(
        child: const Scaffold(
          body: OrphanBanner(orphanCount: 0, onTap: _noop),
        ),
      ));

      // The widget renders a SizedBox.shrink when orphanCount <= 0.
      expect(find.byType(OrphanBanner), findsOneWidget);
      // No text is rendered.
      expect(find.byType(Text), findsNothing);
    },
  );

  // ──────────────────────────────────────────────────────────────────
  // Test 2: orphan banner shows the orphan count and a tap-to-show
  // prompt when orphanCount > 0. Pin the exact text rendered so any
  // change to the l10n strings is caught early.
  // ──────────────────────────────────────────────────────────────────
  testWidgets(
    'OrphanBanner shows the orphan count and tap prompt when '
    'orphanCount > 0',
    (tester) async {
      await tester.pumpWidget(_wrapWithBanner(
        child: const Scaffold(
          body: OrphanBanner(orphanCount: 12, onTap: _noop),
        ),
      ));

      // The widget is in the tree.
      expect(find.byType(OrphanBanner), findsOneWidget);

      // The exact l10n strings are rendered — pin the production copy.
      expect(
        find.text('12 orphan sidechain message(s) — scroll down to see them'),
        findsOneWidget,
        reason: 'main line must match the production l10n string',
      );
      expect(
        find.text('Tap to show 12 more orphan sidechain message(s)'),
        findsOneWidget,
        reason: 'sub line must match the production l10n string',
      );

      // The count chip on the trailing edge of the banner also
      // shows the number.
      expect(find.text('12'), findsOneWidget,
          reason: 'trailing count chip must display the orphan count');

      // The downward arrow icon is rendered.
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    },
  );

  // ──────────────────────────────────────────────────────────────────
  // Test 3: orphan banner tap invokes the onTap callback exactly once.
  // ──────────────────────────────────────────────────────────────────
  testWidgets(
    'OrphanBanner tap invokes onTap once',
    (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(_wrapWithBanner(
        child: Scaffold(
          body: OrphanBanner(
            orphanCount: 3,
            onTap: () => tapCount++,
          ),
        ),
      ));

      // Tap the InkWell inside the banner.
      await tester.tap(find.byType(InkWell));
      await tester.pump();

      expect(tapCount, 1, reason: 'banner tap must invoke onTap once');
    },
  );

  // ──────────────────────────────────────────────────────────────────
  // Test 4: orphan banner hides itself again after a tap+navigate flow
  // (this models the chat screen's _visibleCount increase + re-render
  // with orphanCount == 0 once the orphans are visible).
  // ──────────────────────────────────────────────────────────────────
  testWidgets(
    'OrphanBanner re-renders empty once orphanCount drops to 0',
    (tester) async {
      var showOrphans = true;
      late VoidCallback onTap;

      await tester.pumpWidget(_wrapWithBanner(
        child: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return OrphanBanner(
                orphanCount: showOrphans ? 5 : 0,
                onTap: () {
                  onTap();
                  setState(() {
                    showOrphans = false;
                  });
                },
              );
            },
          ),
        ),
      ));

      // Banner is visible at first.
      expect(
        find.text('5 orphan sidechain message(s) — scroll down to see them'),
        findsOneWidget,
      );

      // Wire the tap AFTER the StatefulBuilder so setState can run.
      onTap = () {
        // The banner's onTap is captured by StatefulBuilder's setState,
        // which calls back into our builder. Setting showOrphans=false
        // there causes the banner to switch to its empty form.
      };

      await tester.tap(find.byType(InkWell));
      await tester.pump();

      // After the state change, no orphan strings are visible.
      expect(
        find.textContaining('orphan sidechain message'),
        findsNothing,
        reason: 'once orphanCount is 0, banner must hide its text',
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

void _noop() {}

Widget _wrapWithBanner({required Widget child}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      // Register the AppColorScheme extension so the banner can read
      // warningContainer / onWarning / warning without crashing when
      // a theme without the extension is provided.
      extensions: [AppColorScheme.light()],
    ),
    home: child,
  );
}