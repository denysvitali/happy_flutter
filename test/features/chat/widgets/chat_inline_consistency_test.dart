import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_inline_row.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/todo.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/core/theme/app_typography.dart';
import 'package:happy_flutter/features/chat/tools/tool_status_indicator.dart';
import 'package:happy_flutter/features/chat/tools/tool_view_widgets.dart';
import 'package:happy_flutter/features/chat/widgets/composer_selector_chip.dart';
import 'package:happy_flutter/features/chat/widgets/session_tasks_banner.dart';
import 'package:happy_flutter/features/chat/widgets/thinking_block.dart';
import 'package:happy_flutter/features/chat/widgets/thinking_stop_bar.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('shared rows: $brightness, text scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container
            .read(todoStateNotifierProvider.notifier)
            .setItemsForSession('session', [
              TodoItem(
                id: 'task',
                content: 'Verify the shared rows',
                status: TodoState.pending,
                priority: 'medium',
                order: 0,
                createdAt: 0,
                updatedAt: 0,
              ),
            ]);
        var stops = 0;
        var details = 0;
        final theme = ThemeData(brightness: brightness);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: theme.copyWith(
                textTheme: AppTypography.applyToTextTheme(theme.textTheme),
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      const ThinkingBlock(content: 'Reasoning content'),
                      ToolHeader(
                        toolIcon: const Icon(Icons.extension_outlined),
                        toolTitle: 'Github-actions: Wait For Commit Checks',
                        state: ToolState.running,
                        createdAt: DateTime.now().millisecondsSinceEpoch,
                        hasContent: true,
                        showCheckFlash: false,
                        chevronAnim: const AlwaysStoppedAnimation(0.0),
                        hasPermissionRequest: false,
                        onTap: () {},
                        onOpenDetails: () => details++,
                      ),
                      const SessionTasksBanner(sessionId: 'session'),
                      ThinkingStopBar(
                        workLabel: 'Using github-actions',
                        startedAt: DateTime.now().millisecondsSinceEpoch,
                        onStop: () => stops++,
                      ),
                      ComposerSelectorChip(label: 'opus:medium', onTap: () {}),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(AppInlineRow), findsNWidgets(4));

        for (final label in [
          'Thinking',
          'Tasks',
          '0 of 1 complete',
          'Using github-actions',
          'Running',
        ]) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.style?.fontSize, AppFontSize.md);
          expect(text.style?.fontFamily, AppTypography.bodyMedium.fontFamily);
        }
        // Selector chips sit one step below the row chrome.
        final chip = tester.widget<Text>(find.text('opus:medium'));
        expect(chip.style?.fontSize, AppFontSize.sm);
        expect(chip.style?.fontFamily, AppTypography.bodyMedium.fontFamily);
        for (final label in ['Stop', 'View all']) {
          final button = tester.widget<TextButton>(
            find.widgetWithText(TextButton, label),
          );
          expect(
            button.style?.textStyle?.resolve({})?.fontSize,
            AppFontSize.md,
          );
          expect(
            tester.getSize(find.widgetWithText(TextButton, label)).height,
            greaterThanOrEqualTo(AppTouchTarget.min),
          );
        }
        await tester.tap(find.text('Stop'));
        await tester.tap(
          find.byKey(const ValueKey('tool-header-details-action')),
        );
        expect(stops, 1);
        expect(details, 1);

        // Copy is an independent action; it must not expand reasoning.
        await tester.tap(find.byIcon(Icons.copy_outlined));
        await tester.pump();
        expect(
          tester
              .widget<SizeTransition>(find.byType(SizeTransition))
              .sizeFactor
              .value,
          0,
        );
        await tester.tap(find.text('Thinking'));
        await tester.pumpAndSettle();
        expect(find.text('Reasoning content'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
