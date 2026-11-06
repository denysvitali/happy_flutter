import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/utils/clipboard_feedback.dart';

void main() {
  late BuildContext ctx;
  Object? failWith;
  String? written;

  setUp(() {
    failWith = null;
    written = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            if (failWith != null) {
              throw PlatformException(code: 'boom');
            }
            written = (call.arguments as Map)['text'] as String?;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  testWidgets('announces a full copy', (tester) async {
    await pump(tester);
    final result = await copyWithFeedback(ctx, 'hello');
    await tester.pump();
    expect(result.success, isTrue);
    expect(written, 'hello');
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('quiet success still reports truncation', (tester) async {
    await pump(tester);
    final result = await copyWithFeedback(
      ctx,
      'x' * 500,
      maxBytes: 100,
      announceSuccess: false,
    );
    await tester.pump();
    expect(result.truncated, isTrue);
    expect(find.textContaining('too large for the clipboard'), findsOneWidget);
    expect(find.textContaining('of 500 characters'), findsOneWidget);
  });

  testWidgets('quiet success shows nothing for a full copy', (tester) async {
    await pump(tester);
    await copyWithFeedback(ctx, 'short', announceSuccess: false);
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('reports failure instead of claiming success', (tester) async {
    failWith = true;
    await pump(tester);
    final result = await copyWithFeedback(ctx, 'hello');
    await tester.pump();
    expect(result.success, isFalse);
    expect(find.text('Copied to clipboard'), findsNothing);
    expect(find.text('Failed to copy text to clipboard'), findsOneWidget);
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, Theme.of(ctx).colorScheme.errorContainer);
  });

  testWidgets('repeated copies replace the toast instead of queueing', (
    tester,
  ) async {
    await pump(tester);
    await copyWithFeedback(ctx, 'one');
    await tester.pump();
    await copyWithFeedback(ctx, 'two', successMessage: 'Copied again');
    await tester.pumpAndSettle();
    expect(find.text('Copied to clipboard'), findsNothing);
    expect(find.text('Copied again'), findsOneWidget);
  });
}
