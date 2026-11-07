import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';
import 'package:happy_flutter/features/chat/chat_input.dart';

void main() {
  testWidgets('render', (tester) async {
    tester.view.physicalSize = const Size(1080, 700);
    tester.view.devicePixelRatio = 2.75;
    final c = TextEditingController(text: 'deselect stuff on mobile), and have overrides for specific team members.\n\nIt\'s also unclear to me when one team member is used, and what is their personality /');
    await tester.pumpWidget(ProviderScope(child: MaterialApp(
      theme: ThemeHelper.buildLightTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Align(alignment: Alignment.bottomCenter,
        child: RepaintBoundary(key: const ValueKey('rb'), child: Padding(
          padding: const EdgeInsets.all(12),
          child: ChatInput(sessionId: 's', controller: c, onSend: () {},
            onPermissionModeChanged: (_) {}))))),
    )));
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      final b = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('rb')));
      final img = await b.toImage(pixelRatio: 2.75);
      final d = await img.toByteData(format: ui.ImageByteFormat.png);
      File('/tmp/composer.png').writeAsBytesSync(d!.buffer.asUint8List());
    });
  });
}
