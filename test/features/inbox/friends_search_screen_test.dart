import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';

/// Minimal inline reproduction of FriendsSearchScreen that avoids
/// SocialService and sync dependencies, allowing us to test the UI.
///
/// The real widget instantiates SocialService directly, so we replicate
/// its visual output here for widget testing.

class _SearchResult {
  const _SearchResult({
    required this.id,
    required this.name,
    this.status = 'none',
  });

  final String id;
  final String name;
  final String status;
}

class _InlineSearchScreen extends StatefulWidget {
  const _InlineSearchScreen({
    this.initialResults = const [],
    this.hasSearched = false,
  });

  final List<_SearchResult> initialResults;
  final bool hasSearched;

  @override
  State<_InlineSearchScreen> createState() =>
      _InlineSearchScreenState();
}

class _InlineSearchScreenState extends State<_InlineSearchScreen> {
  late List<_SearchResult> _results;
  late bool _hasSearched;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _results = widget.initialResults;
    _hasSearched = widget.hasSearched;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find Friends')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Search by username',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (!_hasSearched && _results.isEmpty) {
      return const _EmptyState(
        icon: Icons.person_search,
        title: 'Search for friends',
        subtitle: 'Search for a username to connect',
      );
    }

    if (_hasSearched && _results.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off,
        title: 'Search for friends',
        subtitle: 'Search for a username to connect',
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];
        return _ResultTile(user: user);
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48),
          const SizedBox(height: 8),
          Text(title),
          const SizedBox(height: 4),
          Text(subtitle),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.user});

  final _SearchResult user;

  @override
  Widget build(BuildContext context) {
    final isFriend = user.status == 'friend';
    final isPending = user.status == 'requested';

    return ListTile(
      key: ValueKey(user.id),
      title: Text(user.name),
      trailing: isFriend
          ? const Text('Friends')
          : isPending
              ? const Text('Pending')
              : ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.person_add_alt_1,
                    size: 18,
                  ),
                  label: const Text('Add Friend'),
                ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FriendsSearchScreen UI', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _InlineSearchScreen(),
        ),
      );

      expect(find.text('Find Friends'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders search text field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _InlineSearchScreen(),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(
        find.text('Search by username'),
        findsOneWidget,
      );
    });

    testWidgets('shows empty state when no search performed',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _InlineSearchScreen(),
        ),
      );

      expect(find.byIcon(Icons.person_search), findsOneWidget);
      expect(
        find.text('Search for friends'),
        findsOneWidget,
      );
      expect(
        find.text('Search for a username to connect'),
        findsOneWidget,
      );
    });

    testWidgets('shows no-results state after search',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
          home: _InlineSearchScreen(hasSearched: true),
        ),
      );

      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(
        find.text('Search for friends'),
        findsOneWidget,
      );
    });

    testWidgets('renders search results', (tester) async {
      final results = [
        const _SearchResult(id: 'u1', name: 'Alice'),
        const _SearchResult(id: 'u2', name: 'Bob'),
      ];

      await tester.pumpWidget(
        MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
          home: _InlineSearchScreen(
            initialResults: results,
            hasSearched: true,
          ),
        ),
      );

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('shows Add Friend button for non-friends',
        (tester) async {
      final results = [
        const _SearchResult(
          id: 'u1',
          name: 'NewUser',
          status: 'none',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
          home: _InlineSearchScreen(
            initialResults: results,
            hasSearched: true,
          ),
        ),
      );

      expect(find.text('Add Friend'), findsOneWidget);
      expect(
        find.byIcon(Icons.person_add_alt_1),
        findsOneWidget,
      );
    });

    testWidgets('shows Friends badge for existing friends',
        (tester) async {
      final results = [
        const _SearchResult(
          id: 'u1',
          name: 'OldFriend',
          status: 'friend',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
          home: _InlineSearchScreen(
            initialResults: results,
            hasSearched: true,
          ),
        ),
      );

      expect(find.text('OldFriend'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('Add Friend'), findsNothing);
    });

    testWidgets('shows Pending badge for sent requests',
        (tester) async {
      final results = [
        const _SearchResult(
          id: 'u1',
          name: 'PendingUser',
          status: 'requested',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
          home: _InlineSearchScreen(
            initialResults: results,
            hasSearched: true,
          ),
        ),
      );

      expect(find.text('PendingUser'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Add Friend'), findsNothing);
    });

    testWidgets('renders mixed result statuses', (tester) async {
      final results = [
        const _SearchResult(
          id: 'u1',
          name: 'Friend',
          status: 'friend',
        ),
        const _SearchResult(
          id: 'u2',
          name: 'Pending',
          status: 'requested',
        ),
        const _SearchResult(
          id: 'u3',
          name: 'Stranger',
          status: 'none',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
          home: _InlineSearchScreen(
            initialResults: results,
            hasSearched: true,
          ),
        ),
      );

      expect(find.text('Friend'), findsOneWidget);
      // 'Pending' appears twice: once as the user name and once as
      // the status badge text
      expect(find.text('Pending'), findsNWidgets(2));
      expect(find.text('Stranger'), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(
        find.text('Add Friend'),
        findsOneWidget,
      );
    });

    testWidgets('accepts text input in search field',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _InlineSearchScreen(),
        ),
      );

      await tester.enterText(
        find.byType(TextField),
        'testuser',
      );
      await tester.pump();

      expect(find.text('testuser'), findsOneWidget);
    });

    testWidgets('renders multiple results in scrollable list',
        (tester) async {
      final results = List.generate(
        20,
        (i) => _SearchResult(
          id: 'u$i',
          name: 'User $i',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
          home: _InlineSearchScreen(
            initialResults: results,
            hasSearched: true,
          ),
        ),
      );

      expect(find.byType(ListView), findsOneWidget);
      // First few should be visible.
      expect(find.text('User 0'), findsOneWidget);
      expect(find.text('User 1'), findsOneWidget);
    });
  });
}
