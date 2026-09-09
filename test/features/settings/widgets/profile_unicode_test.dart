import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/models/profile.dart';
import 'package:happy_flutter/core/models/settings.dart';
import 'package:happy_flutter/features/settings/widgets/profile_header.dart';
import 'package:happy_flutter/features/settings/widgets/profile_switcher_tile.dart';

void main() {
  for (final initial in ['a', '😀', '👩🏽‍💻', '🇨🇭', 'e\u0301', '\uD800']) {
    testWidgets('account avatar preserves $initial', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileHeader(
              profile: Profile(id: 'account', firstName: '$initial Name'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text((initial == '\uD800' ? '\uFFFD' : initial).toUpperCase()),
        findsOneWidget,
      );
    });

    testWidgets('backend avatar preserves $initial', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileSwitcherTile(
              profiles: [AIBackendProfile(id: 'custom', name: '$initial Name')],
              selectedProfileId: 'custom',
              onTap: () {},
              title: 'Profiles',
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.text((initial == '\uD800' ? '\uFFFD' : initial).toUpperCase()),
        findsOneWidget,
      );
    });
  }
}
