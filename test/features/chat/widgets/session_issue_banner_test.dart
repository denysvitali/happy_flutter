import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/theme/app_color_scheme.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/chat/widgets/chat_app_bar.dart'
    show SendIssue;
import 'package:happy_flutter/features/chat/widgets/session_issue_banner.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  for (final brightness in Brightness.values) {
    for (final withExtension in [true, false]) {
      testWidgets('warning stays readable and wraps: $brightness, '
          'extension $withExtension', (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final theme = withExtension
            ? (brightness == Brightness.dark
                  ? ThemeHelper.buildDarkTheme()
                  : ThemeHelper.buildLightTheme())
            : ThemeData(brightness: brightness);
        const title = 'Session process stopped';
        const message =
            'The local agent process is gone. Sending a message will '
            'try to restart it and recover this conversation.';
        const action = 'Restart session';
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SessionIssueBanner(
                issue: const SendIssue(
                  title: title,
                  message: message,
                  blocksSend: false,
                ),
                actionLabel: action,
                onAction: () {},
                onCopy: () {},
              ),
            ),
          ),
        );

        final panel = find
            .descendant(
              of: find.byType(SessionIssueBanner),
              matching: find.byType(Material),
            )
            .first;
        final material = tester.widget<Material>(panel);
        final appColors =
            theme.extension<AppColorScheme>() ??
            (brightness == Brightness.dark
                ? AppColorScheme.dark()
                : AppColorScheme.light());
        final panelBounds = tester.getRect(panel);
        for (final label in [title, message, action]) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          final foreground = paragraph.text.style!.color!;
          expect(foreground, appColors.onWarningContainer);
          // The panel is translucent: verify the rendered blend over
          // both the chat surface and the scaffold, not just the token.
          for (final surface in [
            theme.scaffoldBackgroundColor,
            theme.colorScheme.surface,
          ]) {
            final background = Color.alphaBlend(material.color!, surface);
            expect(
              _contrastRatio(foreground, background),
              greaterThanOrEqualTo(4.5),
              reason: '$label must remain readable on its warning panel',
            );
          }
          expect(paragraph.didExceedMaxLines, isFalse, reason: label);
          final bounds = tester.getRect(find.text(label));
          expect(bounds.left, greaterThanOrEqualTo(panelBounds.left));
          expect(bounds.right, lessThanOrEqualTo(panelBounds.right));
          expect(bounds.bottom, lessThanOrEqualTo(panelBounds.bottom));
        }
        final body = tester.widget<Text>(find.text(message));
        expect(
          tester.getSize(find.text(message)).height,
          greaterThan(body.style!.fontSize! * 2 * body.style!.height!),
          reason: 'Long diagnostics must wrap into multiple lines',
        );
        for (final icon in [Icons.restart_alt_rounded, Icons.copy_rounded]) {
          expect(
            tester.widget<Icon>(find.byIcon(icon)).color,
            appColors.onWarningContainer,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('recovery action is distinct from diagnostic copy', (
    tester,
  ) async {
    var recovered = 0;
    var copied = 0;
    await tester.pumpWidget(
      _wrap(
        SessionIssueBanner(
          issue: const SendIssue(
            title: 'Stopped',
            message: 'Start a new conversation.',
            blocksSend: true,
          ),
          actionLabel: 'Start new session',
          onAction: () => recovered++,
          onCopy: () => copied++,
        ),
      ),
    );
    await tester.tap(find.text('Start new session'));
    expect(recovered, 1);
    expect(copied, 0);
    await tester.tap(find.byIcon(Icons.copy_rounded));
    expect(copied, 1);
  });

  testWidgets('renders title and message text', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SessionIssueBanner(
          issue: SendIssue(
            title: 'Session process stopped',
            message:
                'The local agent process is gone. Sending a '
                'message will try to restart it.',
            blocksSend: true,
          ),
        ),
      ),
    );
    expect(find.text('Session process stopped'), findsOneWidget);
    expect(
      find.text(
        'The local agent process is gone. Sending a '
        'message will try to restart it.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('blocksSend=true uses the error icon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SessionIssueBanner(
          issue: SendIssue(
            title: 'Agent failed',
            message: '...',
            blocksSend: true,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.restart_alt_rounded), findsNothing);
  });

  testWidgets('blocksSend=false uses the restart icon', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const SessionIssueBanner(
          issue: SendIssue(
            title: 'Will restart',
            message: '...',
            blocksSend: false,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.restart_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
  });

  testWidgets('shows a copy action when provided', (tester) async {
    var copied = false;
    await tester.pumpWidget(
      _wrap(
        SessionIssueBanner(
          issue: const SendIssue(
            title: 'Agent failed',
            message: 'The process stopped.',
            blocksSend: true,
          ),
          onCopy: () => copied = true,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.copy_rounded));

    expect(copied, isTrue);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return ((a > b ? a : b) + 0.05) / ((a > b ? b : a) + 0.05);
}
