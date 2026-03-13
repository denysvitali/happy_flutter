import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/profile.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/providers/profile_notifier.dart';
import 'package:happy_flutter/features/settings/account_screen.dart';

class _StubProfileNotifier extends ProfileNotifier {
  final Profile? _profile;

  _StubProfileNotifier(this._profile);

  @override
  Profile? build() => _profile;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountScreen', () {
    testWidgets('renders app bar with account settings title',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account Settings'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders back button in app bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('renders profile section with default loading state',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('renders profile section with user display name',
        (tester) async {
      final profile = Profile(
        id: 'test-id',
        firstName: 'John',
        lastName: 'Doe',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith(
              () => _StubProfileNotifier(profile),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('renders profile section with GitHub email',
        (tester) async {
      final profile = Profile(
        id: 'test-id',
        github: GitHubProfile(
          id: 123,
          login: 'johndoe',
          name: 'John Doe',
          avatarUrl: 'https://example.com/avatar.png',
          email: 'john@example.com',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith(
              () => _StubProfileNotifier(profile),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('john@example.com'), findsOneWidget);
    });

    testWidgets('renders default avatar when no avatar URL',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('renders backup key section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BACKUP KEY'), findsOneWidget);
      expect(find.text('Show Backup Key'), findsOneWidget);
      expect(find.text('Copy Backup Key'), findsOneWidget);
      expect(find.byIcon(Icons.key), findsOneWidget);
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
    });

    testWidgets('renders restore section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RESTORE'), findsOneWidget);
      expect(find.text('Restore Account'), findsOneWidget);
      expect(find.byIcon(Icons.restore), findsOneWidget);
    });

    testWidgets('renders devices section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DEVICES'), findsOneWidget);
      expect(find.text('Linked Devices'), findsOneWidget);
      expect(find.text('Link New Device'), findsOneWidget);
      expect(find.byIcon(Icons.devices), findsOneWidget);
      expect(find.byIcon(Icons.add_link), findsOneWidget);
    });

    testWidgets('renders show backup key row with subtitle',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('View your account recovery key'),
        findsOneWidget,
      );
    });

    testWidgets('renders copy backup key row with subtitle',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Copy to clipboard'), findsOneWidget);
    });

    testWidgets('renders restore account row with subtitle',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Recover account from backup key'),
        findsOneWidget,
      );
    });

    testWidgets('renders linked devices row with subtitle',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Manage devices linked to your account'),
        findsOneWidget,
      );
    });

    testWidgets('renders link new device row with subtitle',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Generate QR code for another device'),
        findsOneWidget,
      );
    });

    testWidgets('profile with avatar URL shows CircleAvatar with image',
        (tester) async {
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

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            profileNotifierProvider.overrideWith(
              () => _StubProfileNotifier(profile),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates:
                AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const AccountScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Jane Smith'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });
  });
}
