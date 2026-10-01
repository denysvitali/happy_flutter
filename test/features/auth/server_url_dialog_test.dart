import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/services/server_config.dart';
import 'package:happy_flutter/features/auth/widgets/server_url_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

Widget _wrap(ServerUrlDialog dialog) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: dialog),
);

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'Happy',
      packageName: 'com.example.happy_flutter',
      version: '1.0.0',
      buildNumber: '299500',
      buildSignature: '',
    );
  });

  testWidgets('login dialog submits HTTP Tailscale URL for verification', (
    tester,
  ) async {
    final verification = Completer<ServerUrlVerificationResult>();
    String? submitted;
    await tester.pumpWidget(
      _wrap(
        ServerUrlDialog(
          initialUrl: defaultServerUrl,
          defaultUrl: defaultServerUrl,
          verifyUrl: (url) {
            submitted = url;
            return verification.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Happy 1.0.0+299500'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField),
      ' http://foo.my-tailnet-name.ts.net ',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pump();

    expect(submitted, 'http://foo.my-tailnet-name.ts.net');
    expect(find.textContaining('must use HTTPS'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    verification.complete(
      ServerUrlVerificationResult.failed('Test connection failed', 'Network'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test connection failed'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('login rejection shows parsed host without URL credentials', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      _wrap(
        ServerUrlDialog(
          initialUrl: defaultServerUrl,
          defaultUrl: defaultServerUrl,
          verifyUrl: (_) async {
            calls++;
            return ServerUrlVerificationResult.failed('Unexpected call');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField),
      'http://private:secret@foo.my-tailnet-name.ts.net.evil',
    );
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(calls, 0);
    expect(
      find.textContaining('Hostname: "foo.my-tailnet-name.ts.net.evil"'),
      findsOneWidget,
    );
    expect(find.textContaining('Scheme: "http"'), findsOneWidget);
    final diagnostics = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .data!;
    expect(diagnostics, isNot(contains('private')));
    expect(diagnostics, isNot(contains('secret')));

    await tester.enterText(
      find.byType(TextFormField),
      'http://foo.my-tailnet-name.ts.net',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Hostname:'), findsNothing);
  });

  testWidgets('closing login dialog while verifying is safe', (tester) async {
    final verification = Completer<ServerUrlVerificationResult>();
    await tester.pumpWidget(
      _wrap(
        ServerUrlDialog(
          initialUrl: 'http://foo.my-tailnet-name.ts.net',
          defaultUrl: defaultServerUrl,
          verifyUrl: (_) => verification.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    verification.complete(
      ServerUrlVerificationResult.failed('Late connection failure'),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
