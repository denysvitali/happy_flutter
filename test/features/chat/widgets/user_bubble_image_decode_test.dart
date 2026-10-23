import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

Future<Uint8List> _sizedPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

Future<Size> _decodedSize(ImageProvider provider) async {
  final result = Completer<Size>();
  final stream = provider.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener(
    (info, _) {
      result.complete(
        Size(info.image.width.toDouble(), info.image.height.toDouble()),
      );
      info.dispose();
    },
    onError: (Object error, StackTrace? stack) {
      result.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  try {
    return await result.future;
  } finally {
    stream.removeListener(listener);
  }
}

Widget _bubble(Uint8List bytes) => UserBubble(
  text: '',
  imageBlocks: [
    {
      'type': 'image',
      'source': {'type': 'base64', 'data': base64Encode(bytes)},
    },
  ],
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
              UserBubble(
                text: '',
                imageBlocks: [
                  {
                    'type': 'image',
                    'source': {'type': 'base64', 'data': data},
                  },
                ],
              ),
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

    Image image(WidgetTester t) => t.widget<Image>(find.byType(Image).first);
    final resizeBefore = image(tester).image as ResizeImage;
    final providerBefore = (resizeBefore.imageProvider as MemoryImage).bytes;

    // Parent rebuilds with unchanged payload — exactly what happens on
    // every message tick while a session streams.
    await tester.tap(find.byType(TextButton));
    await tester.pump();

    expect(rebuildTick, 1);
    final resizeAfter = image(tester).image as ResizeImage;
    expect(resizeAfter, resizeBefore);
    final providerAfter = (resizeAfter.imageProvider as MemoryImage).bytes;
    expect(
      identical(providerBefore, providerAfter),
      isTrue,
      reason:
          'a new Uint8List identity would miss the ImageCache and '
          're-decode the full-resolution pixels on every tick',
    );
    expect(providerBefore, _pngBytes());
  });

  for (final scenario in [
    (name: 'portrait', width: 600, height: 1200, pane: 800.0, dpr: 2.0),
    (name: 'landscape', width: 1600, height: 800, pane: 800.0, dpr: 1.0),
    (name: 'narrow pane', width: 1600, height: 800, pane: 240.0, dpr: 3.0),
    (name: 'small original', width: 40, height: 80, pane: 800.0, dpr: 2.5),
  ]) {
    testWidgets('${scenario.name} decode fits DPR-aware thumbnail bounds', (
      tester,
    ) async {
      final bytes = await tester.runAsync(
        () => _sizedPng(scenario.width, scenario.height),
      );
      tester.view.devicePixelRatio = scenario.dpr;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _host(SizedBox(width: scenario.pane, child: _bubble(bytes!))),
      );

      final imageFinder = find.byType(Image);
      final provider = tester.widget<Image>(imageFinder).image as ResizeImage;
      final constraints = tester
          .renderObject<RenderBox>(imageFinder)
          .constraints;
      expect(provider.policy, ResizeImagePolicy.fit);
      expect(provider.allowUpscaling, isFalse);
      expect(provider.width, (constraints.maxWidth * scenario.dpr).ceil());
      expect(provider.height, (220 * scenario.dpr).ceil());
      final decoded = await tester.runAsync(() => _decodedSize(provider));
      expect(decoded!.width, lessThanOrEqualTo(provider.width!));
      expect(decoded.height, lessThanOrEqualTo(provider.height!));
      expect(decoded.width, lessThanOrEqualTo(scenario.width));
      expect(decoded.height, lessThanOrEqualTo(scenario.height));
      // Integer decode dimensions can round by one pixel.
      expect(
        decoded.width,
        closeTo(decoded.height * scenario.width / scenario.height, 2),
      );
      if (scenario.name == 'narrow pane') {
        expect(decoded.width, provider.width);
        expect(decoded.height, lessThan(provider.height!));
      } else if (scenario.name == 'small original') {
        expect(decoded, const Size(40, 80));
      } else {
        expect(decoded.height, provider.height);
      }
      await tester.pump();
      final rendered = tester.getSize(imageFinder);
      expect(rendered.height, lessThanOrEqualTo(220));
      expect(rendered.width, lessThanOrEqualTo(constraints.maxWidth));
      expect(
        rendered.width / rendered.height,
        closeTo(decoded.width / decoded.height, 0.01),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pane and DPR changes update targets but reuse original bytes', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() => _sizedPng(1600, 800));
    Future<void> show(double pane, double dpr) async {
      tester.view.devicePixelRatio = dpr;
      await tester.pumpWidget(
        _host(SizedBox(width: pane, child: _bubble(bytes!))),
      );
    }

    addTearDown(tester.view.resetDevicePixelRatio);
    await show(600, 1);
    ResizeImage provider() =>
        tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    final before = provider();
    await show(240, 1);
    final narrow = provider();
    expect(narrow.width, lessThan(before.width!));
    expect(narrow.height, before.height);
    expect(narrow.imageProvider, before.imageProvider);
    await show(240, 2);
    final highDpr = provider();
    expect(highDpr.width, closeTo(narrow.width! * 2, 1));
    expect(highDpr.height, narrow.height! * 2);
    expect(highDpr.imageProvider, before.imageProvider);
  });

  testWidgets('fullscreen uses original bytes without a resize provider', (
    tester,
  ) async {
    final bytes = await tester.runAsync(() => _sizedPng(1200, 600));
    await tester.pumpWidget(_host(_bubble(bytes!)));
    final thumbnail =
        tester.widget<Image>(find.byType(Image)).image as ResizeImage;
    final memory = thumbnail.imageProvider as MemoryImage;
    await tester.runAsync(() => _decodedSize(thumbnail));
    await tester.pump();
    await tester.tap(find.byType(Image));
    await tester.pumpAndSettle();

    final fullscreen = tester.widget<Image>(
      find.descendant(
        of: find.byType(InteractiveViewer),
        matching: find.byType(Image),
      ),
    );
    expect(fullscreen.image, isA<MemoryImage>());
    expect(
      identical((fullscreen.image as MemoryImage).bytes, memory.bytes),
      isTrue,
    );
    final decoded = await tester.runAsync(() => _decodedSize(fullscreen.image));
    expect(decoded, const Size(1200, 600));
    expect(tester.takeException(), isNull);
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
              'source': {'type': 'base64', 'data': '!!! not base64 !!!'},
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
