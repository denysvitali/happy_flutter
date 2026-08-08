import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/features/chat/widgets/session_info_widgets.dart';

Widget _app(Metadata metadata) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SessionSandboxBadge(metadata: metadata)),
  );
}

void main() {
  testWidgets('shows verified enforcement', (tester) async {
    await tester.pumpWidget(
      _app(
        const Metadata(
          host: 'devbox',
          sandboxRequested: true,
          sandboxEnforced: true,
          sandboxBackend: 'boxy',
        ),
      ),
    );

    expect(find.text('Sandboxed'), findsOneWidget);
  });

  testWidgets('warns when requested isolation was not enforced', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const Metadata(
          host: 'devbox',
          sandboxRequested: true,
          sandboxEnforced: false,
          sandboxBackend: 'none',
          sandboxReason: 'boxy doctor failed',
        ),
      ),
    );

    expect(find.text('Not sandboxed'), findsOneWidget);
    expect(find.byTooltip('boxy doctor failed'), findsOneWidget);
  });

  testWidgets('stays hidden for legacy sessions without enforcement data', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const Metadata(host: 'devbox')));

    expect(find.text('Sandboxed'), findsNothing);
    expect(find.text('Not sandboxed'), findsNothing);
  });
}
