import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/theme/code_viewer_theme.dart';
import 'package:happy_flutter/features/chat/widgets/error_message_widget.dart';

/// Finds the "Debug data" JSON box [Container] (monospace [SelectableText]
/// child, [BoxDecoration] background).
Finder _debugBox() => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.child is SelectableText &&
      (w.child as SelectableText).style?.fontFamily == 'monospace',
);

Finder _debugText() => find.byWidgetPredicate(
  (w) => w is SelectableText && w.style?.fontFamily == 'monospace',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child, {required CodeViewerTheme code}) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(extensions: <ThemeExtension<dynamic>>[code]),
      home: Scaffold(body: child),
    );
  }

  const messageData = <String, dynamic>{
    'errorType': 'decrypt_failed',
    'errorMessage': 'Boom',
    'id': 'm1',
    'seq': 3,
    'createdAt': 0,
    'debugData': <String, dynamic>{'k': 'v'},
  };

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byType(ErrorMessageWidget));
    await tester.pumpAndSettle();
  }

  testWidgets('debug box follows the light CodeViewerTheme', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ErrorMessageWidget(messageData: messageData),
        code: CodeViewerTheme.light,
      ),
    );
    await openSheet(tester);

    final box = tester.widget<Container>(_debugBox());
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, CodeViewerTheme.light.background);

    final text = tester.widget<SelectableText>(_debugText());
    expect(text.style?.color, CodeViewerTheme.light.foreground);
  });

  testWidgets('debug box follows the dark CodeViewerTheme', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ErrorMessageWidget(messageData: messageData),
        code: CodeViewerTheme.dark,
      ),
    );
    await openSheet(tester);

    final box = tester.widget<Container>(_debugBox());
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, CodeViewerTheme.dark.background);

    final text = tester.widget<SelectableText>(_debugText());
    expect(text.style?.color, CodeViewerTheme.dark.foreground);

    // Regression guard: the box must not be the old hardcoded VSCode hexes,
    // which ignored theme brightness.
    expect(decoration.color, isNot(const Color(0xFF1E1E1E)));
    expect(text.style?.color, isNot(const Color(0xFF9CDCFE)));
  });
}
