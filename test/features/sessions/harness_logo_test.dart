import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/prime_agent_logo.dart';
import 'package:happy_flutter/features/sessions/harness_logo.dart';
import 'package:happy_flutter/features/sessions/session_avatar.dart';

void main() {
  const flavors = [
    'claude',
    'codex',
    'agy',
    'pi',
    'opencode',
    'grok',
    'grok-build',
    'gemini',
    'har',
    'prime-agent',
  ];

  for (final brightness in Brightness.values) {
    for (final flavor in flavors) {
      testWidgets('$flavor has a shared logo in $brightness', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: SessionAvatar(id: 'session', flavor: flavor),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(HarnessLogo), findsOneWidget);
        expect(
          tester.widget<HarnessLogo>(find.byType(HarnessLogo)).flavor,
          flavor,
        );
        if (flavor == 'prime-agent') {
          expect(find.byType(PrimeAgentLogo), findsOneWidget);
        } else if (flavor == 'har') {
          expect(find.byType(Image), findsNothing);
          expect(find.byIcon(Icons.terminal_rounded), findsOneWidget);
        } else {
          expect(find.byIcon(Icons.terminal_rounded), findsNothing);
          final image = tester.widget<Image>(find.byType(Image));
          final asset = image.image as ResizeImage;
          final path = (asset.imageProvider as AssetImage).assetName;
          expect(path, switch (flavor) {
            'codex' => 'assets/images/icon-gpt.png',
            'agy' || 'gemini' => 'assets/images/icon-gemini.png',
            'grok-build' => 'assets/images/icon-grok.png',
            _ => 'assets/images/icon-$flavor.png',
          });
          // The monochrome OpenAI mark must follow the theme, not stay black.
          expect(
            image.color,
            flavor == 'codex'
                ? Theme.of(
                    tester.element(find.byType(Image)),
                  ).colorScheme.onSurface
                : isNull,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
