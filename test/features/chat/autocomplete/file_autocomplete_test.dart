import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/autocomplete/file_autocomplete.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── findActiveWord ────────────────────────────────────────────────

  group('findActiveWord', () {
    test('returns null when text has a selection range', () {
      const content = 'hello @file';
      const selection = TextSelection(baseOffset: 6, extentOffset: 11);
      expect(findActiveWord(content, selection), isNull);
    });

    test('returns null when cursor at beginning', () {
      const content = '@file';
      const selection = TextSelection.collapsed(offset: 0);
      expect(findActiveWord(content, selection), isNull);
    });

    test('detects @ prefix word at end of text', () {
      const content = 'hello @main.dart';
      // cursor after '@' → selection.start=7
      const selection = TextSelection.collapsed(offset: 7);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@main.dart');
      expect(word.activeWord, '@');
      expect(word.offset, 6);
    });

    test('detects @ prefix word in middle of text', () {
      const content = 'look at @file.txt for details';
      // cursor after 'txt' → offset 17
      const selection = TextSelection.collapsed(offset: 17);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@file.txt');
      expect(word.offset, 8);
    });

    test('returns partial word when cursor is mid-word', () {
      const content = 'open @main.dart';
      // cursor after '@mai' → offset 10
      const selection = TextSelection.collapsed(offset: 10);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.activeWord, '@mai');
      expect(word.word, '@main.dart');
    });

    test('detects : prefix word', () {
      const content = 'use :emoji';
      // cursor after ':emoji' → offset 10
      const selection = TextSelection.collapsed(offset: 10);
      final word = findActiveWord(content, selection, ['@', ':', '/']);
      expect(word, isNotNull);
      expect(word!.word, ':emoji');
      expect(word.offset, 4);
    });

    test('detects / prefix word', () {
      const content = 'type /help';
      // cursor after '/help' → offset 10
      const selection = TextSelection.collapsed(offset: 10);
      final word = findActiveWord(content, selection, ['@', ':', '/']);
      expect(word, isNotNull);
      expect(word!.word, '/help');
      expect(word.offset, 5);
    });

    test('returns null when cursor after space without prefix', () {
      const content = 'hello world';
      // cursor after 'hello' → offset 5
      const selection = TextSelection.collapsed(offset: 5);
      expect(findActiveWord(content, selection), isNull);
    });

    test('returns null when cursor after a stop character', () {
      const content = 'hello, @file';
      // cursor after ',' → offset 6
      const selection = TextSelection.collapsed(offset: 6);
      expect(findActiveWord(content, selection), isNull);
    });

    test('handles @ at beginning of text', () {
      const content = '@main.dart is the entry point';
      // cursor after 't' in 'dart' → offset 9
      const selection = TextSelection.collapsed(offset: 9);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@main.dart');
      expect(word.offset, 0);
    });

    test('handles file paths with slashes', () {
      const content = 'check @lib/main.dart';
      // cursor after 'dart' → offset 20
      const selection = TextSelection.collapsed(offset: 20);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@lib/main.dart');
      expect(word.offset, 6);
    });

    test('handles nested file paths', () {
      const content = 'edit @src/features/chat/file.dart';
      // cursor after '.dart' → offset 33
      const selection = TextSelection.collapsed(offset: 33);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@src/features/chat/file.dart');
      expect(word.offset, 5);
    });

    test('returns just prefix when no content after it', () {
      const content = 'hello @';
      // cursor after '@' → offset 7
      const selection = TextSelection.collapsed(offset: 7);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@');
      expect(word.activeWord, '@');
      expect(word.activeLength, 1);
    });

    test('stops at newline', () {
      const content = 'hello\n@file';
      // cursor after 'file' → offset 11
      const selection = TextSelection.collapsed(offset: 11);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@file');
      expect(word.offset, 6);
    });

    test('stops at parentheses', () {
      const content = '(@file)';
      // cursor after 'file' → offset 6
      const selection = TextSelection.collapsed(offset: 6);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@file');
      expect(word.offset, 1);
    });

    test('custom prefixes only match specified chars', () {
      const content = 'use :emoji';
      // cursor after ':emoji' → offset 10
      const selection = TextSelection.collapsed(offset: 10);
      // Only @ prefix, so :emoji should not be detected
      final word = findActiveWord(content, selection, ['@']);
      expect(word, isNull);
    });

    test('returns endOffset pointing past the word', () {
      const content = 'hello @file.txt world';
      // cursor after '.txt' → offset 16
      const selection = TextSelection.collapsed(offset: 16);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.endOffset, 16);
      expect(content.substring(word.offset, word.endOffset), '@file.txt');
    });

    test('stops at space after word', () {
      const content = '@file more text';
      // cursor after 'file' → offset 5
      const selection = TextSelection.collapsed(offset: 5);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@file');
      expect(word.endOffset, 5);
    });

    test('returns null when no prefix in word', () {
      const content = 'hello world';
      // cursor after 'world' → offset 11
      const selection = TextSelection.collapsed(offset: 11);
      expect(findActiveWord(content, selection), isNull);
    });

    test('returns null when cursor after stop char .', () {
      const content = 'hello.world @file';
      // cursor after '.' → offset 6
      const selection = TextSelection.collapsed(offset: 6);
      expect(findActiveWord(content, selection), isNull);
    });

    test('handles multiple @ in text', () {
      const content = '@first @second';
      // cursor after 'second' → offset 15
      const selection = TextSelection.collapsed(offset: 15);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@second');
      expect(word.offset, 7);
    });
  });

  // ── getActiveWordQuery ────────────────────────────────────────────

  group('getActiveWordQuery', () {
    test('strips prefix from word', () {
      expect(getActiveWordQuery('@main.dart'), 'main.dart');
    });

    test('returns empty for single char prefix', () {
      expect(getActiveWordQuery('@'), '');
    });

    test('strips colon prefix', () {
      expect(getActiveWordQuery(':smile'), 'smile');
    });

    test('strips slash prefix', () {
      expect(getActiveWordQuery('/help'), 'help');
    });

    test('handles nested paths', () {
      expect(
        getActiveWordQuery('@src/features/chat.dart'),
        'src/features/chat.dart',
      );
    });
  });

  // ── applySuggestion ───────────────────────────────────────────────

  group('applySuggestion', () {
    test('replaces @ word with suggestion', () {
      const content = 'hello @mai world';
      // cursor after '@mai' → offset 10
      const selection = TextSelection.collapsed(offset: 10);
      final result = applySuggestion(
        content,
        selection,
        '@main.dart',
        const ['@'],
        true,
      );
      expect(result.text, 'hello @main.dart world');
      expect(result.cursorPosition, 16);
    });

    test('adds space after suggestion when at end', () {
      const content = 'hello @mai';
      // cursor after '@mai' → offset 10
      const selection = TextSelection.collapsed(offset: 10);
      final result = applySuggestion(
        content,
        selection,
        '@main.dart',
        const ['@'],
        true,
      );
      expect(result.text, 'hello @main.dart ');
      expect(result.cursorPosition, 17);
    });

    test('does not add extra space when one already exists', () {
      const content = 'hello @mai world';
      // cursor after '@mai' → offset 10
      const selection = TextSelection.collapsed(offset: 10);
      final result = applySuggestion(
        content,
        selection,
        '@main.dart',
        const ['@'],
        true,
      );
      expect(result.text, 'hello @main.dart world');
    });

    test('no trailing space when addSpace is false', () {
      const content = 'hello @mai';
      // cursor after '@mai' → offset 10
      const selection = TextSelection.collapsed(offset: 10);
      final result = applySuggestion(
        content,
        selection,
        '@main.dart',
        const ['@'],
        false,
      );
      expect(result.text, 'hello @main.dart');
      expect(result.cursorPosition, 16);
    });

    test('inserts at cursor when no active word found', () {
      const content = 'hello world';
      // cursor after 'hello' → offset 5
      const selection = TextSelection.collapsed(offset: 5);
      final result = applySuggestion(
        content,
        selection,
        '@file',
        const ['@'],
        true,
      );
      expect(result.text, 'hello@file world');
    });

    test('handles empty content', () {
      const content = '';
      const selection = TextSelection.collapsed(offset: 0);
      final result = applySuggestion(
        content,
        selection,
        '@file',
        const ['@'],
        true,
      );
      expect(result.text, '@file ');
    });

    test('replaces mid-word prefix with suggestion', () {
      const content = 'open @lib/main.dart';
      // cursor after '@lib' → offset 9
      const selection = TextSelection.collapsed(offset: 9);
      final result = applySuggestion(
        content,
        selection,
        '@lib/models/user.dart',
        const ['@'],
        true,
      );
      expect(result.text, 'open @lib/models/user.dart ');
      expect(result.cursorPosition, 26);
    });

    test('replaces complete word when cursor is mid-word', () {
      const content = 'check @main.dart';
      // cursor after '@main' → offset 11
      const selection = TextSelection.collapsed(offset: 11);
      final result = applySuggestion(
        content,
        selection,
        '@main_test.dart',
        const ['@'],
        true,
      );
      expect(result.text, 'check @main_test.dart ');
    });

    test('preserves text before and after replacement', () {
      const content = 'prefix @file suffix';
      // cursor after '@file' → offset 11
      const selection = TextSelection.collapsed(offset: 11);
      final result = applySuggestion(
        content,
        selection,
        '@file.dart',
        const ['@'],
        true,
      );
      expect(result.text, 'prefix @file.dart suffix');
    });

    test('works with colon prefix', () {
      const content = 'hello :sm world';
      // cursor after ':sm' → offset 8
      const selection = TextSelection.collapsed(offset: 8);
      final result = applySuggestion(
        content,
        selection,
        ':smile',
        const [':'],
        true,
      );
      expect(result.text, 'hello :smile world');
    });

    test('works with slash prefix', () {
      const content = 'run /he world';
      // cursor after '/he' → offset 8
      const selection = TextSelection.collapsed(offset: 8);
      final result = applySuggestion(
        content,
        selection,
        '/help',
        const ['/'],
        true,
      );
      expect(result.text, 'run /help world');
    });
  });

  // ── FileSuggestion ────────────────────────────────────────────────

  group('FileSuggestion', () {
    test('equality based on label and path', () {
      const a = FileSuggestion(label: 'main.dart', path: 'lib/main.dart');
      const b = FileSuggestion(label: 'main.dart', path: 'lib/main.dart');
      expect(a, equals(b));
    });

    test('inequality on different label', () {
      const a = FileSuggestion(label: 'main.dart', path: 'lib/main.dart');
      const b = FileSuggestion(label: 'app.dart', path: 'lib/main.dart');
      expect(a, isNot(equals(b)));
    });

    test('inequality on different path', () {
      const a = FileSuggestion(label: 'main.dart', path: 'lib/main.dart');
      const b = FileSuggestion(label: 'main.dart', path: 'src/main.dart');
      expect(a, isNot(equals(b)));
    });

    test('hashCode matches for equal objects', () {
      const a = FileSuggestion(label: 'main.dart', path: 'lib/main.dart');
      const b = FileSuggestion(label: 'main.dart', path: 'lib/main.dart');
      expect(a.hashCode, equals(b.hashCode));
    });

    test('type defaults to file', () {
      const suggestion = FileSuggestion(
        label: 'main.dart',
        path: 'lib/main.dart',
      );
      expect(suggestion.type, FileSuggestionType.file);
    });

    test('can set type to folder', () {
      const suggestion = FileSuggestion(
        label: 'lib',
        path: 'lib',
        type: FileSuggestionType.folder,
      );
      expect(suggestion.type, FileSuggestionType.folder);
    });

    test('different types with same label/path are equal', () {
      const a = FileSuggestion(
        label: 'lib',
        path: 'lib',
        type: FileSuggestionType.folder,
      );
      const b = FileSuggestion(
        label: 'lib',
        path: 'lib',
        type: FileSuggestionType.file,
      );
      // Equality ignores type
      expect(a, equals(b));
    });
  });

  // ── FileAutocomplete widget ───────────────────────────────────────

  group('FileAutocomplete', () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    Widget buildAutocomplete({
      required Future<List<FileSuggestion>> Function(String) fetchSuggestions,
      void Function(FileSuggestion)? onSelect,
    }) {
      return _wrap(
        FileAutocomplete(
          controller: controller,
          focusNode: focusNode,
          fetchSuggestions: fetchSuggestions,
          onSelect: onSelect ?? (_) {},
          child: TextField(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );
    }

    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [],
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('does not show overlay initially', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [],
        ),
      );

      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('shows overlay with suggestions after typing @query', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@main';
      // cursor after '@main' → offset 5
      controller.selection = const TextSelection.collapsed(offset: 5);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('main.dart'), findsOneWidget);
      expect(find.text('lib/main.dart'), findsOneWidget);
    });

    testWidgets('hides overlay when text has no @ prefix', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = 'hello world';
      controller.selection = const TextSelection.collapsed(offset: 11);
      controller.notifyListeners();
      await tester.pump();

      expect(find.text('main.dart'), findsNothing);
    });

    testWidgets('hides overlay when cursor is at beginning', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@main';
      controller.selection = const TextSelection.collapsed(offset: 0);
      controller.notifyListeners();
      await tester.pump();

      expect(find.text('main.dart'), findsNothing);
    });

    testWidgets('calls onSelect when suggestion is tapped', (tester) async {
      FileSuggestion? selected;

      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
          ],
          onSelect: (s) => selected = s,
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@main';
      controller.selection = const TextSelection.collapsed(offset: 5);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('main.dart'));
      await tester.pump();

      expect(selected, isNotNull);
      expect(selected!.label, 'main.dart');
      expect(selected!.path, 'lib/main.dart');
    });

    testWidgets('applies suggestion to text on tap', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@mai';
      // cursor after '@mai' → offset 4
      controller.selection = const TextSelection.collapsed(offset: 4);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('main.dart'));
      await tester.pump();

      expect(controller.text, '@main.dart ');
    });

    testWidgets('hides overlay after selecting suggestion', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@mai';
      controller.selection = const TextSelection.collapsed(offset: 4);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('main.dart'), findsOneWidget);

      await tester.tap(find.text('main.dart'));
      await tester.pump();

      expect(find.text('main.dart'), findsNothing);
    });

    testWidgets('shows file icon for file suggestions', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
              type: FileSuggestionType.file,
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@main';
      controller.selection = const TextSelection.collapsed(offset: 5);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });

    testWidgets('shows folder icon for folder suggestions', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'lib',
              path: 'lib',
              type: FileSuggestionType.folder,
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@lib';
      controller.selection = const TextSelection.collapsed(offset: 4);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });

    testWidgets('shows type badge for files', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
              type: FileSuggestionType.file,
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@main';
      controller.selection = const TextSelection.collapsed(offset: 5);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('File'), findsOneWidget);
    });

    testWidgets('shows type badge for folders', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'lib',
              path: 'lib',
              type: FileSuggestionType.folder,
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@lib';
      controller.selection = const TextSelection.collapsed(offset: 4);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Folder'), findsOneWidget);
    });

    testWidgets('hides overlay when focus is lost', (tester) async {
      final otherFocus = FocusNode();
      addTearDown(otherFocus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FileAutocomplete(
                  controller: controller,
                  focusNode: focusNode,
                  fetchSuggestions: (_) async => [
                    const FileSuggestion(
                      label: 'main.dart',
                      path: 'lib/main.dart',
                    ),
                  ],
                  onSelect: (_) {},
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                  ),
                ),
                TextField(focusNode: otherFocus),
              ],
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@main';
      controller.selection = const TextSelection.collapsed(offset: 5);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('main.dart'), findsOneWidget);

      // Move focus to other field
      otherFocus.requestFocus();
      await tester.pump();

      expect(find.text('main.dart'), findsNothing);
    });

    testWidgets('shows multiple suggestions', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
            const FileSuggestion(
              label: 'app.dart',
              path: 'lib/app.dart',
            ),
            const FileSuggestion(
              label: 'utils.dart',
              path: 'lib/utils.dart',
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@d';
      controller.selection = const TextSelection.collapsed(offset: 2);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('main.dart'), findsOneWidget);
      expect(find.text('app.dart'), findsOneWidget);
      expect(find.text('utils.dart'), findsOneWidget);
    });

    testWidgets('filters suggestions by query', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
            const FileSuggestion(
              label: 'app.dart',
              path: 'lib/app.dart',
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@app';
      controller.selection = const TextSelection.collapsed(offset: 4);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('app.dart'), findsOneWidget);
      expect(find.text('main.dart'), findsNothing);
    });

    testWidgets('handles fetch error gracefully', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async {
            throw Exception('network error');
          },
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@main';
      controller.selection = const TextSelection.collapsed(offset: 5);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should not crash, overlay should be hidden
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('hides overlay when query is just @', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@';
      controller.selection = const TextSelection.collapsed(offset: 1);
      controller.notifyListeners();
      await tester.pump();

      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('shows separator between suggestions', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
            const FileSuggestion(
              label: 'app.dart',
              path: 'lib/app.dart',
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@a';
      controller.selection = const TextSelection.collapsed(offset: 2);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Divider separates the two suggestions
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('selects first suggestion by default', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
            const FileSuggestion(
              label: 'app.dart',
              path: 'lib/app.dart',
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@a';
      controller.selection = const TextSelection.collapsed(offset: 2);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // First item should be selected (highlighted)
      final items = find.byType(InkWell);
      expect(items, findsNWidgets(2));
    });

    testWidgets('shows no divider for single suggestion', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@main';
      controller.selection = const TextSelection.collapsed(offset: 5);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('shows loading indicator while fetching', (tester) async {
      final completer =
          Completer<List<FileSuggestion>>();

      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) => completer.future,
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@main';
      controller.selection = const TextSelection.collapsed(offset: 5);
      controller.notifyListeners();
      await tester.pump();

      // Loading indicator should be visible while fetch is pending
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Searching files...'), findsOneWidget);

      // Complete the fetch
      completer.complete([
        const FileSuggestion(label: 'main.dart', path: 'lib/main.dart'),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Loading indicator should disappear, suggestions should show
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('main.dart'), findsOneWidget);
    });

    testWidgets('applies suggestion and keeps focus', (tester) async {
      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) async => [
            const FileSuggestion(
              label: 'main.dart',
              path: 'lib/main.dart',
            ),
          ],
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.text = '@mai';
      controller.selection = const TextSelection.collapsed(offset: 4);
      controller.notifyListeners();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('main.dart'));
      await tester.pump();

      // Focus should remain on the input
      expect(focusNode.hasFocus, isTrue);
    });
  });
}
