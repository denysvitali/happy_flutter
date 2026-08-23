import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/profile.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/profile_notifier.dart';
import 'package:happy_flutter/core/widgets/network_avatar_image.dart';
import 'package:happy_flutter/features/settings/account_screen.dart';

class _StubProfileNotifier extends ProfileNotifier {
  final Profile? _profile;

  _StubProfileNotifier(this._profile);

  @override
  Profile? build() => _profile;
}

Future<List<ConnectedServiceInfo>> _emptyConnectedServices() async => [];

Future<void> _pumpAccountScreen(WidgetTester tester, {Profile? profile}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (profile != null)
          profileNotifierProvider.overrideWith(
            () => _StubProfileNotifier(profile),
          ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (_) =>
                AccountScreen(loadConnectedServices: _emptyConnectedServices),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountScreen', () {
    testWidgets('renders app bar with account settings title', (tester) async {
      await _pumpAccountScreen(tester);

      expect(find.text('Account Settings'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders back button in app bar', (tester) async {
      await _pumpAccountScreen(tester);

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('renders profile header with fallback identity', (
      tester,
    ) async {
      await _pumpAccountScreen(tester);

      // ProfileHeader falls back to the app name and tagline when no
      // profile has loaded yet.
      expect(find.text('Happy'), findsOneWidget);
      expect(
        find.text('Secure mobile companion for your sessions'),
        findsOneWidget,
      );
    });

    testWidgets('renders profile section with user display name', (
      tester,
    ) async {
      final profile = Profile(
        id: 'test-id',
        firstName: 'John',
        lastName: 'Doe',
      );

      await _pumpAccountScreen(tester, profile: profile);

      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('renders profile header with GitHub bio', (tester) async {
      final profile = Profile(
        id: 'test-id',
        github: GitHubProfile(
          id: 123,
          login: 'johndoe',
          name: 'John Doe',
          avatarUrl: 'https://example.com/avatar.png',
          email: 'john@example.com',
          bio: 'Building Happy',
        ),
      );

      await _pumpAccountScreen(tester, profile: profile);

      expect(find.text('Building Happy'), findsOneWidget);
    });

    testWidgets('renders initial avatar when no avatar URL', (tester) async {
      await _pumpAccountScreen(tester);

      // ProfileHeader falls back to an initial-letter avatar for the
      // fallback display name "Happy".
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('H'), findsOneWidget);
    });

    testWidgets('renders backup key section', (tester) async {
      await _pumpAccountScreen(tester);

      expect(find.text('BACKUP KEY'), findsOneWidget);
      expect(find.text('Show Backup Key'), findsOneWidget);
      expect(find.text('Copy Backup Key'), findsOneWidget);
      expect(find.byIcon(Icons.key), findsOneWidget);
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
    });

    testWidgets('renders restore section', (tester) async {
      await _pumpAccountScreen(tester);

      expect(find.text('RESTORE'), findsOneWidget);
      expect(find.text('Restore Account'), findsOneWidget);
      expect(find.byIcon(Icons.restore), findsOneWidget);
    });

    testWidgets('renders devices section', (tester) async {
      await _pumpAccountScreen(tester);

      expect(find.text('DEVICES'), findsOneWidget);
      expect(find.text('Linked Devices'), findsOneWidget);
      expect(find.text('Link New Device'), findsOneWidget);
      expect(find.byIcon(Icons.devices), findsOneWidget);
      expect(find.byIcon(Icons.add_link), findsOneWidget);
    });

    testWidgets('renders show backup key row with subtitle', (tester) async {
      await _pumpAccountScreen(tester);

      expect(find.text('View your account recovery key'), findsOneWidget);
    });

    testWidgets('renders copy backup key row with subtitle', (tester) async {
      await _pumpAccountScreen(tester);

      expect(find.text('Copy to clipboard'), findsOneWidget);
    });

    testWidgets('renders restore account row with subtitle', (tester) async {
      await _pumpAccountScreen(tester);

      expect(find.text('Recover account from backup key'), findsOneWidget);
    });

    testWidgets('renders linked devices row with subtitle', (tester) async {
      await _pumpAccountScreen(tester);

      expect(
        find.text('Manage devices linked to your account'),
        findsOneWidget,
      );
    });

    testWidgets('renders link new device row with subtitle', (tester) async {
      await _pumpAccountScreen(tester);

      expect(find.text('Generate QR code for another device'), findsOneWidget);
    });

    testWidgets('profile with avatar URL shows NetworkAvatarImage', (
      tester,
    ) async {
      final profile = Profile(
        id: 'test-id',
        firstName: 'Jane',
        lastName: 'Smith',
        avatar: const ImageRef(
          width: 200,
          height: 200,
          thumbhash: 'abc',
          path: '/avatar.jpg',
          url: 'https://example.com/avatar.jpg',
        ),
      );

      await _pumpAccountScreen(tester, profile: profile);

      expect(find.text('Jane Smith'), findsOneWidget);
      expect(find.byType(NetworkAvatarImage), findsOneWidget);
    });
  });
}
