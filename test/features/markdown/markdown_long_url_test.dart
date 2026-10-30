import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/markdown/markdown_view.dart';

const _longUrl =
    'https://claude.com/cai/oauth/authorize?code=true'
    '&client_id=9d1c250a-e61b-44d9-88ed-5944d1962f5e'
    '&response_type=code&state=f2b9c1';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shortenLongBareUrls', () {
    test(
      'labels a long bare URL by host and path, keeping the full target',
      () {
        expect(
          shortenLongBareUrls('1. Open this link: $_longUrl'),
          '1. Open this link: [claude.com/cai/oauth/authorize…]($_longUrl)',
        );
      },
    );

    test('keeps sentence punctuation outside the link', () {
      expect(
        shortenLongBareUrls('Open $_longUrl.'),
        'Open [claude.com/cai/oauth/authorize…]($_longUrl).',
      );
    });

    test('leaves short URLs, existing links and code untouched', () {
      const short = 'See https://example.com/docs for more.';
      expect(shortenLongBareUrls(short), short);
      const linked = '[sign in]($_longUrl)';
      expect(shortenLongBareUrls(linked), linked);
      const inline = 'Run `curl $_longUrl` first.';
      expect(shortenLongBareUrls(inline), inline);
      const fenced = '```\n$_longUrl\n```';
      expect(shortenLongBareUrls(fenced), fenced);
    });
  });

  testWidgets('the short label opens the complete URL', (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    // No '&' here: this checks the tap target, not markdown entity handling.
    const target =
        'https://claude.com/cai/oauth/authorize'
        '?client=9d1c250a-e61b-44d9-88ed-5944d1962f5e';

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MarkdownView(markdown: target)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('claude.com/cai/oauth/authorize…'),
      findsOneWidget,
    );
    expect(find.textContaining('9d1c250a'), findsNothing);

    await tester.tap(find.textContaining('claude.com/cai/oauth/authorize…'));
    await tester.pumpAndSettle();

    expect(calls, isNotEmpty);
    expect(calls.first.arguments, containsPair('url', target));
  });
}
