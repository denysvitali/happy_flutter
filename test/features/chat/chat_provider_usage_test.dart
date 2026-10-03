import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/built_in_profiles.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/widgets/app_linear_progress_indicator.dart';
import 'package:happy_flutter/features/chat/widgets/chat_provider_usage.dart';

Widget _app(
  ChatUsageFetcher fetch, {
  String machineId = 'machine-1',
  String flavor = 'codex',
  bool visible = true,
  double textScale = 1,
  VoidCallback? onTap,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: TickerMode(
      enabled: visible,
      child: ChatProviderUsage(
        machineId: machineId,
        flavor: flavor,
        fetch: fetch,
        onTap: onTap ?? () {},
      ),
    ),
  ),
);

void main() {
  test('usage is limited to known official profiles', () {
    expect(officialUsageFlavor('codex', null), 'codex');
    expect(officialUsageFlavor('claude', null), 'claude');
    expect(officialUsageFlavor(null, null), 'claude');
    expect(
      officialUsageFlavor('claude', getBuiltInProfile('anthropic')),
      'claude',
    );
    expect(officialUsageFlavor('claude', getBuiltInProfile('minimax')), isNull);
    expect(
      officialUsageFlavor('codex', getBuiltInProfile('anthropic')),
      isNull,
    );
    expect(
      officialUsageFlavor(
        'codex',
        AIBackendProfile(
          id: 'proxy',
          name: 'Proxy',
          codexModelProvider: 'proxy',
        ),
      ),
      isNull,
    );
    expect(
      officialUsageFlavor(
        'claude',
        AIBackendProfile(id: 'anthropic', name: 'Custom gateway'),
      ),
      isNull,
    );
    expect(
      officialUsageFlavor(
        'claude',
        AIBackendProfile(
          id: 'anthropic',
          name: 'Gateway',
          isBuiltIn: true,
          anthropicConfig: AnthropicConfig(baseUrl: 'https://proxy.example'),
        ),
      ),
      isNull,
    );
    expect(officialUsageFlavor('grok', null), isNull);
  });

  testWidgets('machine limits fit mobile and open details on tap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var tapped = false;
    await tester.pumpWidget(
      _app((machineId, flavor) async {
        expect(machineId, 'machine-1');
        expect(flavor, 'codex');
        return const [
          ChatUsageWindow('5-Hour', 24),
          ChatUsageWindow('7-Day', 68),
        ];
      }, onTap: () => tapped = true),
    );
    await tester.pump();
    expect(find.text('24%'), findsOneWidget);
    expect(find.text('68%'), findsOneWidget);
    final semantics = tester
        .getSemantics(find.byType(LinearProgressIndicator).first)
        .getSemanticsData();
    expect(semantics.value, '24');
    expect(semantics.label, isNotEmpty);
    expect(find.byType(AppLinearProgressIndicator), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('24%'));
    expect(tapped, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('polling pauses when hidden and refreshes on return', (
    tester,
  ) async {
    var calls = 0;
    Future<List<ChatUsageWindow>> fetch(String machine, String flavor) async {
      calls++;
      return [ChatUsageWindow('5-Hour', calls.toDouble())];
    }

    await tester.pumpWidget(_app(fetch));
    await tester.pump();
    expect(calls, 1);
    await tester.pump(const Duration(minutes: 1));
    expect(calls, 2);
    await tester.pumpWidget(_app(fetch, visible: false));
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 2);
    await tester.pumpWidget(_app(fetch));
    await tester.pump();
    expect(calls, 3);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 3);
  });

  testWidgets(
    'pending requests do not overlap and old machine data is ignored',
    (tester) async {
      final old = Completer<List<ChatUsageWindow>>();
      var calls = 0;
      Future<List<ChatUsageWindow>> fetch(String machine, String flavor) {
        calls++;
        return machine == 'machine-1'
            ? old.future
            : Future.value(const [ChatUsageWindow('5-Hour', 12)]);
      }

      await tester.pumpWidget(_app(fetch));
      await tester.pump(const Duration(minutes: 2));
      expect(calls, 1);
      await tester.pumpWidget(_app(fetch, machineId: 'machine-2'));
      await tester.pump();
      expect(find.text('12%'), findsOneWidget);
      old.complete(const [ChatUsageWindow('5-Hour', 99)]);
      await tester.pump();
      expect(find.text('99%'), findsNothing);
      expect(find.text('12%'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('failed refresh keeps bars with a stale label', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _app((machine, flavor) async {
        if (++calls > 1) throw StateError('offline');
        return const [ChatUsageWindow('5-Hour', 45)];
      }),
    );
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    await tester.pump();
    final context = tester.element(find.byType(ChatProviderUsage));
    expect(
      find.text(AppLocalizations.of(context).providersUsageStale),
      findsOneWidget,
    );
    expect(find.text('45%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('backgrounding pauses polling and resumes with fresh limits', (
    tester,
  ) async {
    var calls = 0;
    Future<List<ChatUsageWindow>> fetch(String machine, String flavor) async {
      calls++;
      return const [ChatUsageWindow('5-Hour', 20)];
    }

    await tester.pumpWidget(_app(fetch));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    expect(calls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty and failed reports never invent zero usage', (
    tester,
  ) async {
    Future<List<ChatUsageWindow>> empty(String machine, String flavor) async =>
        [];
    await tester.pumpWidget(_app(empty));
    await tester.pump();
    expect(find.byType(AppLinearProgressIndicator), findsNothing);
    expect(find.text('0%'), findsNothing);
    await tester.pumpWidget(
      _app((machine, flavor) async {
        throw StateError('unavailable');
      }),
    );
    await tester.pump();
    expect(find.byType(AppLinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Claude model windows clamp values and support large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      _app(
        (machine, flavor) async => const [
          ChatUsageWindow('7-Day Sonnet', 110),
          ChatUsageWindow('7-Day Opus', -1),
        ],
        flavor: 'claude',
        textScale: 2,
      ),
    );
    await tester.pump();
    final bars = tester
        .widgetList<AppLinearProgressIndicator>(
          find.byType(AppLinearProgressIndicator),
        )
        .toList();
    expect(bars.map((bar) => bar.value), [1.0, 0.0]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
