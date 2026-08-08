import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/components/app_loading_indicator.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/provider_usage.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/providers/providers_usage_screen.dart';

class _StubSettingsNotifier extends SettingsNotifier {
  @override
  Settings build() => Settings();

  @override
  Future<void> updateSetting<T>(String key, T value) async {}
}

class _StubProviderUsageNotifier extends ProviderUsageNotifier {
  _StubProviderUsageNotifier(this.initial, {this.loadGate});

  final ProviderUsageSummary initial;
  final Completer<void>? loadGate;

  @override
  ProviderUsageSummary build() => initial;

  @override
  Future<void> loadAccounts() async {
    await loadGate?.future;
  }

  @override
  Future<void> refreshUsage() async {}
}

Widget _app(ProviderUsageSummary summary, {Completer<void>? loadGate}) {
  return ProviderScope(
    overrides: [
      settingsNotifierProvider.overrideWith(_StubSettingsNotifier.new),
      providerUsageNotifierProvider.overrideWith(
        () => _StubProviderUsageNotifier(summary, loadGate: loadGate),
      ),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ProvidersUsageScreen(),
    ),
  );
}

const _healthyUsage = ProviderUsage(
  accountId: 'healthy',
  type: ProviderUsageType.kimi,
  accountName: 'Healthy account',
  windows: [ProviderUsageWindow(label: 'Daily', utilization: 25)],
);

const _errorUsage = ProviderUsage(
  accountId: 'broken',
  type: ProviderUsageType.zai,
  accountName: 'Broken account',
  error: 'Authentication failed',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('distinguishes first load from a genuine empty state', (
    tester,
  ) async {
    final loadGate = Completer<void>();
    await tester.pumpWidget(
      _app(const ProviderUsageSummary(), loadGate: loadGate),
    );
    await tester.pump();

    expect(find.byType(AppLoadingIndicator), findsOneWidget);
    expect(find.text('No provider accounts'), findsNothing);

    loadGate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AppLoadingIndicator), findsNothing);
    expect(find.text('No provider accounts'), findsOneWidget);
  });

  testWidgets('keeps stale accounts visible and explains refresh state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const ProviderUsageSummary(
          usages: [_healthyUsage],
          isLoading: true,
          globalError: 'Network unavailable',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Healthy account'), findsOneWidget);
    expect(find.text('Updating usage…'), findsOneWidget);
    expect(find.text('Usage may be stale'), findsOneWidget);
    expect(find.text('Network unavailable'), findsOneWidget);
  });

  testWidgets('orders attention accounts first and exposes textual health', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const ProviderUsageSummary(usages: [_healthyUsage, _errorUsage])),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1 account needs attention'), findsOneWidget);
    expect(find.text('Needs attention'), findsWidgets);
    expect(find.text('Healthy'), findsWidgets);

    final brokenY = tester.getTopLeft(find.text('Broken account')).dy;
    final healthyY = tester.getTopLeft(find.text('Healthy account')).dy;
    expect(brokenY, lessThan(healthyY));
  });

  testWidgets('long press preserves selection with selected semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const ProviderUsageSummary(usages: [_errorUsage])),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final account = find.bySemanticsLabel('Broken account, Needs attention');
    expect(account, findsOneWidget);
    await tester.longPress(account);
    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget);
    expect(
      tester.getSemantics(account).flagsCollection.isSelected,
      Tristate.isTrue,
    );
  });
}
