import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/session.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/features/command_palette/command_item.dart';
import 'package:happy_flutter/features/command_palette/command_palette.dart';
import 'package:happy_flutter/features/command_palette/command_palette_overlay.dart';

class _FakeSessionsNotifier extends SessionsNotifier {
  @override
  Map<String, Session> build() => {};
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

List<CommandItem> _sampleCommands() {
  return [
    CommandItem(
      id: 'new-session',
      title: 'New Session',
      subtitle: 'Start a new chat session',
      icon: Icons.add_circle_outline,
      category: 'Sessions',
      shortcut: 'Ctrl+N',
      action: () {},
    ),
    CommandItem(
      id: 'settings',
      title: 'Settings',
      subtitle: 'Configure preferences',
      icon: Icons.settings_outlined,
      category: 'Navigation',
      shortcut: 'Ctrl+,',
      action: () {},
    ),
    CommandItem(
      id: 'inbox',
      title: 'Inbox',
      icon: Icons.inbox_outlined,
      category: 'Navigation',
      action: () {},
    ),
    CommandItem(
      id: 'zen',
      title: 'Zen Mode',
      subtitle: 'Focus mode',
      icon: Icons.emoji_nature_outlined,
      category: 'Navigation',
      action: () {},
    ),
  ];
}

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

// ---------------------------------------------------------------------------
// CommandItem / CommandCategory model tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CommandItem', () {
    test('stores all fields correctly', () {
      var called = false;
      final item = CommandItem(
        id: 'test-id',
        title: 'Test Title',
        subtitle: 'Test Subtitle',
        icon: Icons.star,
        shortcut: 'Ctrl+T',
        category: 'General',
        action: () => called = true,
      );

      expect(item.id, 'test-id');
      expect(item.title, 'Test Title');
      expect(item.subtitle, 'Test Subtitle');
      expect(item.icon, Icons.star);
      expect(item.shortcut, 'Ctrl+T');
      expect(item.category, 'General');

      item.action();
      expect(called, isTrue);
    });

    test('optional fields default to null', () {
      final item = CommandItem(id: 'minimal', title: 'Minimal', action: () {});

      expect(item.subtitle, isNull);
      expect(item.icon, isNull);
      expect(item.shortcut, isNull);
      expect(item.category, isNull);
    });

    test('copyWith overrides specified fields', () {
      final original = CommandItem(
        id: 'orig',
        title: 'Original',
        subtitle: 'Sub',
        icon: Icons.star,
        shortcut: 'Ctrl+A',
        category: 'Cat',
        action: () {},
      );

      final copied = original.copyWith(title: 'Updated', shortcut: 'Ctrl+B');

      expect(copied.id, 'orig');
      expect(copied.title, 'Updated');
      expect(copied.subtitle, 'Sub');
      expect(copied.icon, Icons.star);
      expect(copied.shortcut, 'Ctrl+B');
      expect(copied.category, 'Cat');
    });

    test('copyWith preserves action when not overridden', () {
      var callCount = 0;
      final original = CommandItem(
        id: 'a',
        title: 'A',
        action: () => callCount++,
      );

      final copied = original.copyWith(title: 'B');
      copied.action();
      expect(callCount, 1);
    });
  });

  group('CommandCategory', () {
    test('stores fields correctly', () {
      final commands = _sampleCommands().sublist(0, 2);
      final cat = CommandCategory(
        id: 'nav',
        title: 'Navigation',
        commands: commands,
      );

      expect(cat.id, 'nav');
      expect(cat.title, 'Navigation');
      expect(cat.commands, hasLength(2));
    });
  });

  // -----------------------------------------------------------------------
  // CommandPaletteOverlay widget tests
  // -----------------------------------------------------------------------

  group('CommandPaletteOverlay', () {
    testWidgets('renders search field and all commands', (tester) async {
      final commands = _sampleCommands();

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      // Search field present
      expect(find.byType(TextField), findsOneWidget);

      // All command titles rendered
      expect(find.text('New Session'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Zen Mode'), findsOneWidget);
    });

    testWidgets('renders subtitles when provided', (tester) async {
      final commands = _sampleCommands();

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      // Commands with subtitles
      expect(find.text('Start a new chat session'), findsOneWidget);
      expect(find.text('Configure preferences'), findsOneWidget);
      expect(find.text('Focus mode'), findsOneWidget);
    });

    testWidgets('renders shortcuts when provided', (tester) async {
      final commands = _sampleCommands();

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ctrl+N'), findsOneWidget);
      expect(find.text('Ctrl+,', findRichText: true), findsOneWidget);
    });

    testWidgets('renders category headers', (tester) async {
      final commands = _sampleCommands();

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Navigation'), findsOneWidget);
    });

    testWidgets('renders ESC badge', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          CommandPaletteOverlay(commands: _sampleCommands(), onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ESC'), findsOneWidget);
    });

    testWidgets('renders search icon', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(
          CommandPaletteOverlay(commands: _sampleCommands(), onClose: () {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    // -- Search / filter --

    testWidgets('filters commands by title', (tester) async {
      final commands = _sampleCommands();

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'settings');
      await tester.pumpAndSettle();

      // Only Settings command visible
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('New Session'), findsNothing);
      expect(find.text('Inbox'), findsNothing);
      expect(find.text('Zen Mode'), findsNothing);
    });

    testWidgets('search-only commands stay indexed without crowding defaults', (
      tester,
    ) async {
      final commands = [
        ..._sampleCommands(),
        CommandItem(
          id: 'older-session',
          title: 'Archived investigation',
          action: () {},
          searchOnly: true,
        ),
      ];
      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('Archived investigation'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Archived investigation');
      await tester.pump(const Duration(milliseconds: 150));
      // The query remains visible in the search field and the matching
      // command is rendered as a separate result.
      expect(find.text('Archived investigation'), findsNWidgets(2));
    });

    testWidgets('filters commands by subtitle', (tester) async {
      final commands = _sampleCommands();

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'focus');
      await tester.pumpAndSettle();

      expect(find.text('Zen Mode'), findsOneWidget);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('shows empty state when no commands match', (tester) async {
      final commands = _sampleCommands();

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyznonexistent');
      await tester.pumpAndSettle();

      expect(find.text('No commands found'), findsOneWidget);
      expect(find.text('Try a different search term'), findsOneWidget);
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('filter is case-insensitive', (tester) async {
      final commands = _sampleCommands();

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'SETTINGS');
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('New Session'), findsNothing);
    });

    testWidgets('clearing search restores all commands', (tester) async {
      final commands = _sampleCommands();

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'settings');
      await tester.pumpAndSettle();
      expect(find.text('Inbox'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.text('New Session'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Zen Mode'), findsOneWidget);
    });

    // -- Command tap --

    testWidgets('tapping a command fires action and closes', (tester) async {
      var actionCalled = false;
      var closeCalled = false;
      final commands = [
        CommandItem(
          id: 'test',
          title: 'Test Command',
          icon: Icons.star,
          action: () => actionCalled = true,
        ),
      ];

      await tester.pumpWidget(
        _wrapWithApp(
          CommandPaletteOverlay(
            commands: commands,
            onClose: () => closeCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Test Command'));
      await tester.pumpAndSettle();

      expect(closeCalled, isTrue);
      expect(actionCalled, isTrue);
    });

    // -- Keyboard navigation --

    testWidgets('escape key calls onClose', (tester) async {
      var closeCalled = false;

      await tester.pumpWidget(
        _wrapWithApp(
          CommandPaletteOverlay(
            commands: _sampleCommands(),
            onClose: () => closeCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Send escape key event to the overlay
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(closeCalled, isTrue);
    });

    testWidgets('enter key executes selected command', (tester) async {
      var actionCalled = false;
      final commands = [
        CommandItem(
          id: 'first',
          title: 'First Command',
          icon: Icons.star,
          action: () => actionCalled = true,
        ),
      ];

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(actionCalled, isTrue);
    });

    // -- Icons --

    testWidgets('renders command icons', (tester) async {
      final commands = _sampleCommands();

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.byIcon(Icons.emoji_nature_outlined), findsOneWidget);
    });

    testWidgets('commands without icon do not render icon widget', (
      tester,
    ) async {
      final commands = [
        CommandItem(id: 'no-icon', title: 'No Icon Command', action: () {}),
      ];

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Icon Command'), findsOneWidget);
      // The command item should not have an icon container
      expect(find.byIcon(Icons.star), findsNothing);
    });

    // -- Default category --

    testWidgets('commands without category are grouped under General', (
      tester,
    ) async {
      final commands = [
        CommandItem(id: 'uncat', title: 'Uncategorized', action: () {}),
      ];

      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: commands, onClose: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('General'), findsOneWidget);
      expect(find.text('Uncategorized'), findsOneWidget);
    });

    // -- Empty command list --

    testWidgets('renders empty state for empty command list', (tester) async {
      await tester.pumpWidget(
        _wrapWithApp(CommandPaletteOverlay(commands: const [], onClose: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('No commands found'), findsOneWidget);
    });
  });

  // -----------------------------------------------------------------------
  // CommandPaletteVisibleNotifier tests
  // -----------------------------------------------------------------------

  group('CommandPaletteVisibleNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is false', () {
      final visible = container.read(commandPaletteVisibleProvider);
      expect(visible, isFalse);
    });

    test('show() sets state to true', () {
      container.read(commandPaletteVisibleProvider.notifier).show();
      expect(container.read(commandPaletteVisibleProvider), isTrue);
    });

    test('hide() sets state to false', () {
      container.read(commandPaletteVisibleProvider.notifier).show();
      container.read(commandPaletteVisibleProvider.notifier).hide();
      expect(container.read(commandPaletteVisibleProvider), isFalse);
    });

    test('toggle() flips state', () {
      final notifier = container.read(commandPaletteVisibleProvider.notifier);

      expect(container.read(commandPaletteVisibleProvider), isFalse);

      notifier.toggle();
      expect(container.read(commandPaletteVisibleProvider), isTrue);

      notifier.toggle();
      expect(container.read(commandPaletteVisibleProvider), isFalse);
    });
  });

  // -----------------------------------------------------------------------
  // CommandPaletteOverlayWrapper tests
  // -----------------------------------------------------------------------

  group('CommandPaletteOverlayWrapper', () {
    testWidgets('renders SizedBox.shrink when not visible', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _wrapWithApp(const CommandPaletteOverlayWrapper()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SizedBox), findsOneWidget);
      expect(find.byType(CommandPaletteOverlay), findsNothing);
    });

    testWidgets('renders CommandPaletteOverlay when visible', (tester) async {
      final container = ProviderContainer(
        overrides: [
          sessionsNotifierProvider.overrideWith(() => _FakeSessionsNotifier()),
        ],
      );

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const CommandPaletteOverlayWrapper(),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Make palette visible
      container.read(commandPaletteVisibleProvider.notifier).show();
      await tester.pumpAndSettle();

      expect(find.byType(CommandPaletteOverlay), findsOneWidget);

      router.dispose();
      container.dispose();
    });

    testWidgets('app host provides a modal barrier and isolates focus', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          sessionsNotifierProvider.overrideWith(() => _FakeSessionsNotifier()),
        ],
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: TextField(key: ValueKey('route-field'))),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => CommandPaletteKeyboardHandler(
              appRouter: router,
              child: CommandPaletteAppOverlay(appRouter: router, child: child!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('route-field')));
      await tester.pump();
      final routeEditable = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('route-field')),
          matching: find.byType(EditableText),
        ),
      );
      expect(routeEditable.focusNode.hasFocus, isTrue);

      container.read(commandPaletteVisibleProvider.notifier).show();
      await tester.pumpAndSettle();

      expect(find.byType(CommandPaletteOverlay), findsOneWidget);
      expect(find.byType(ModalBarrier), findsOneWidget);
      expect(
        find.byKey(const ValueKey('command-palette-modal')),
        findsOneWidget,
      );
      final focusGate = tester.widget<ExcludeFocus>(
        find.byKey(const ValueKey('command-palette-background')),
      );
      expect(focusGate.excluding, isTrue);

      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();

      expect(find.byType(CommandPaletteOverlay), findsNothing);
      expect(routeEditable.focusNode.hasFocus, isTrue);

      router.dispose();
      container.dispose();
    });
  });
}
