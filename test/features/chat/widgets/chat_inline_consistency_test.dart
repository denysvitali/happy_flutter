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

        // Transcript rows (thinking, tool calls) share the 13sp row style.
        for (final label in ['Thinking', 'Running']) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.style?.fontSize, AppFontSize.md);
          expect(text.style?.fontFamily, AppTypography.bodyMedium.fontFamily);
        }
        // Composer chrome (task / activity rows and selector chips) is one
        // smaller, quieter 11sp style, clearly below the 14sp draft.
        for (final label in [
          'Tasks',
          '0 of 1 complete',
          'Using github-actions',
          'opus:medium',
        ]) {
          final text = tester.widget<Text>(find.text(label));
          expect(text.style?.fontSize, AppFontSize.xs, reason: label);
          expect(text.style?.fontFamily, AppTypography.bodyMedium.fontFamily);
        }
        for (final label in ['Stop', 'View all']) {
          final button = tester.widget<TextButton>(
            find.widgetWithText(TextButton, label),
          );
          expect(
            button.style?.textStyle?.resolve({})?.fontSize,
            AppFontSize.xs,
          );
          expect(
            tester.getSize(find.widgetWithText(TextButton, label)).height,
            greaterThanOrEqualTo(AppControlSize.sm),
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

  testWidgets('warning and neutral composer chips share one text style', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              ComposerSelectorChip(label: 'YOLO', warning: true, onTap: () {}),
              ComposerSelectorChip(label: 'sonnet:high', onTap: () {}),
            ],
          ),
        ),
      ),
    );
    final warning = tester.widget<Text>(find.text('YOLO')).style!;
    final neutral = tester.widget<Text>(find.text('sonnet:high')).style!;
    expect(warning.fontSize, neutral.fontSize);
    expect(warning.fontWeight, neutral.fontWeight);
    expect(warning.fontFamily, neutral.fontFamily);
  });
}
