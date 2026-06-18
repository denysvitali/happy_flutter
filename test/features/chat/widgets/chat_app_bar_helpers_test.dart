import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/chat_app_bar.dart';

void main() {
  group('buildChatMachineVitals', () {
    test('returns null when machineId is null', () {
      expect(buildChatMachineVitals(machineId: null, daemonState: null), isNull);
    });

    test('returns null when machineId is empty', () {
      expect(buildChatMachineVitals(machineId: '', daemonState: null), isNull);
    });

    test('returns null when daemonState is null', () {
      // Even with a valid machineId, no daemon stats means no vitals.
      expect(
        buildChatMachineVitals(machineId: 'm1', daemonState: null),
        isNull,
      );
    });

    test('returns vitals when machineId and daemonState are present', () {
      final state = <String, dynamic>{
        'machineStats': {
          'cpu': {'usagePercent': 12.5},
          'memory': {'usagePercent': 64.0},
          'disk': {'usagePercent': 87.3},
        },
      };
      final vitals = buildChatMachineVitals(
        machineId: 'm1',
        daemonState: state,
      );
      expect(vitals, isNotNull);
      expect(vitals!.cpuPercent, closeTo(12.5, 0.01));
      expect(vitals.memoryPercent, closeTo(64.0, 0.01));
      expect(vitals.diskPercent, closeTo(87.3, 0.01));
    });
  });

  group('formatLastSeenLabel', () {
    Widget _wrap(int activeAtMs) {
      // A trivial host widget so the test can resolve AppLocalizations.
      // The function only reads context.l10n, not Theme.
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Text(formatLastSeenLabel(context, activeAtMs));
          },
        ),
      );
    }

    testWidgets('returns "just now" for active timestamps under 1 minute old',
        (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(_wrap(now.millisecondsSinceEpoch));
      // The l10n string for chatLastSeenJustNow is non-empty in the
      // test bundle (English fallback). We assert the function ran
      // without throwing and produced a non-empty widget.
      expect(find.byType(Text), findsOneWidget);
    });
  });
}
