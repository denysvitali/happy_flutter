import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/user_bubble.dart';

/// Progressive-lag remediation, third pass 2026-08-24.
///
/// The inline base64 image used to decode inside `build`: every parent
/// rebuild (each message tick while a session streams) re-ran
/// `base64Decode` on a potentially multi-MB payload and minted a fresh
/// `MemoryImage`, whose new bytes identity missed the global ImageCache —
/// a full-resolution re-decode per tick of pure garbage, matching the
/// GC-stall frozen-frame signature. These tests pin the once-per-payload
/// decode: rebuilds reuse the identical bytes instance, and a malformed
/// payload renders a placeholder instead of crashing the bubble.

Uint8List _pngBytes() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8'
  'BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

// Delegates go on MaterialApp: its own inner LocalizationsScope wins the
// lookup, so an outer Localizations wrapper would leave
// AppLocalizations.of(context) null.
Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('rebuilds reuse the identical decoded bytes instance', (
    tester,
  ) async {
    final data = base64Encode(_pngBytes());
    var rebuildTick = 0;

    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              UserBubble(text: '', imageBlocks: [
                {
                  'type': 'image',
                  'source': {'type': 'base64', 'data': data},
                },
              ]),
              Text('tick $rebuildTick'),
              TextButton(
                onPressed: () => setState(() => rebuildTick++),
                child: const Text('rebuild'),
              ),
            ],
          ),
        ),
      ),
    );

    Image image(WidgetTester t) =>
        t.widget<Image>(find.byType(Image).first) as Image;
    final providerBefore = (image(tester).image as MemoryImage).bytes;

    // Parent rebuilds with unchanged payload — exactly what happens on
    // every message tick while a session streams.
    await tester.tap(find.byType(TextButton));
    await tester.pump();

    expect(rebuildTick, 1);
    final providerAfter = (image(tester).image as MemoryImage).bytes;
    expect(
      identical(providerBefore, providerAfter),
      isTrue,
      reason:
          'a new Uint8List identity would miss the ImageCache and '
          're-decode the full-resolution pixels on every tick',
    );
    expect(providerBefore, _pngBytes());
  });

  testWidgets('a malformed base64 payload renders a placeholder, '
      'not a crash', (tester) async {
    await tester.pumpWidget(
      _host(
        UserBubble(
          text: '',
          imageBlocks: [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'data': '!!! not base64 !!!',
              },
            },
          ],
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });
}
