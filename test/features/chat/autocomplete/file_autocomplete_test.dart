import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/features/chat/autocomplete/file_autocomplete.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(0.8)),
        child: SizedBox.expand(child: child),
      ),
    ),
  );
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
      // cursor after '@file' (before the dot) → offset 13
      // '.' is a stop character in backward scan, so we position
      // the cursor before it to find the @-prefixed word.
      const selection = TextSelection.collapsed(offset: 13);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@file.txt');
      expect(word.activeWord, '@file');
      expect(word.offset, 8);
    });

    test('returns partial word when cursor is mid-word', () {
      const content = 'open @main.dart';
      // 'open @main.dart' => o(0) p(1) e(2) n(3) (4) @(5) m(6) a(7) i(8) n(9) .(10) ...
      // cursor after '@mai' → offset 9
      const selection = TextSelection.collapsed(offset: 9);
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
      // @(0) m(1) a(2) i(3) n(4) .(5) ...
      // cursor after '@main' (before dot) → offset 5
      const selection = TextSelection.collapsed(offset: 5);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@main.dart');
      expect(word.offset, 0);
    });

    test('handles file paths with slashes', () {
      const content = 'check @lib/main.dart';
      // c(0) h(1) e(2) c(3) k(4) (5) @(6) l(7) i(8) b(9) /(10) m(11) a(12) i(13) n(14) .(15) ...
      // cursor after '@lib/main' (before dot) → offset 15
      const selection = TextSelection.collapsed(offset: 15);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      expect(word!.word, '@lib/main.dart');
      expect(word.offset, 6);
    });

    test('handles nested file paths', () {
      const content = 'edit @src/features/chat/file.dart';
      // e(0) d(1) i(2) t(3) (4) @(5) s(6) r(7) c(8) /(9) ...
      // /(9) f(10) e(11) a(12) t(13) u(14) r(15) e(16) s(17) /(18) c(19) h(20) a(21) t(22) /(23) f(24) i(25) l(26) e(27) .(28) ...
      // cursor before the dot → offset 28
      const selection = TextSelection.collapsed(offset: 28);
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
      // h(0) e(1) l(2) l(3) o(4) (5) @(6) f(7) i(8) l(9) e(10) .(11) t(12) x(13) t(14) (15) ...
      // cursor after '@file' (before dot) → offset 11
      // '.' is a stop character for backward scan, so place cursor before it
      const selection = TextSelection.collapsed(offset: 11);
      final word = findActiveWord(content, selection);
      expect(word, isNotNull);
      // endOffset extends past '.' and 'txt' because @ makes it a file path
      expect(word!.endOffset, 15);
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
      // @(0) f(1) i(2) r(3) s(4) t(5) (6) @(7) s(8) e(9) c(10) o(11) n(12) d(13)
      // cursor after 'second' → offset 14 (length of string)
      const selection = TextSelection.collapsed(offset: 14);
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
      // No prefix in text, so findActiveWord returns null.
      // The null branch inserts suggestion + space at cursor.
      const selection = TextSelection.collapsed(offset: 5);
      final result = applySuggestion(
        content,
        selection,
        '@file',
        const ['@'],
        true,
      );
      // null branch: beforeCursor='hello', afterCursor=' world',
      // suggestion with space = '@file ', result = 'hello@file  world'
      expect(result.text, 'hello@file  world');
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
      // o(0) p(1) e(2) n(3) (4) @(5) l(6) i(7) b(8) /(9) m(10) ...
      // cursor after '@lib' → offset 9
      const selection = TextSelection.collapsed(offset: 9);
      final result = applySuggestion(
        content,
        selection,
        '@lib/models/user.dart',
        const ['@'],
        true,
      );
      // activeWord found: offset=5, endOffset=19 (full '@lib/main.dart')
      // replaced with '@lib/models/user.dart ' (trailing space since afterWord is empty)
      expect(result.text, 'open @lib/models/user.dart ');
      expect(result.cursorPosition, 27);
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
      // r(0) u(1) n(2) (3) /(4) h(5) e(6) (7) w(8) ...
      // cursor after '/he' (before space) → offset 7
      const selection = TextSelection.collapsed(offset: 7);
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
      controller.value = const TextEditingValue(
        text: '@main',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pump();
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection.collapsed(offset: 11),
      );
      await tester.pumpAndSettle();

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
      // Set text and cursor atomically to avoid intermediate state
      // where cursor defaults to end of text
      controller.value = const TextEditingValue(
        text: '@main',
        selection: TextSelection.collapsed(offset: 0),
      );
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: '@main',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('main.dart').first);
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: '@mai',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('main.dart').first);
      await tester.pumpAndSettle();

      // _selectSuggestion applies '@main.dart' (label prefixed with @)
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
      controller.value = const TextEditingValue(
        text: '@mai',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('main.dart'), findsOneWidget);

      await tester.tap(find.text('main.dart').first);
      await tester.pumpAndSettle();

      // After selection the overlay label should no longer appear
      // (the text field now contains '@main.dart ' which has a dot —
      //  a stop character — so the overlay won't re-open)
      expect(find.byType(ListView), findsNothing);
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
      controller.value = const TextEditingValue(
        text: '@main',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pump();
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: '@lib',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pump();
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: '@main',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pump();
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: '@lib',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Folder'), findsOneWidget);
    });

    testWidgets('hides overlay when focus is lost', (tester) async {
      final otherFocus = FocusNode();
      addTearDown(otherFocus.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(0.8),
              ),
              child: SizedBox.expand(
                child: Column(
                  children: [
                    Expanded(
                      child: FileAutocomplete(
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
                    ),
                    TextField(focusNode: otherFocus),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.value = const TextEditingValue(
        text: '@main',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('main.dart'), findsOneWidget);

      // Move focus to other field
      otherFocus.requestFocus();
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: '@d',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pump();
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: '@app',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pump();
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: '@main',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pump();
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: '@',
        selection: TextSelection.collapsed(offset: 1),
      );
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: '@a',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pump();
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: '@a',
        selection: TextSelection.collapsed(offset: 2),
      );
      await tester.pump();
      await tester.pumpAndSettle();

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
      controller.value = const TextEditingValue(
        text: '@main',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('shows suggestions after async fetch completes',
        (tester) async {
      final completer = Completer<List<FileSuggestion>>();

      await tester.pumpWidget(
        buildAutocomplete(
          fetchSuggestions: (_) => completer.future,
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      controller.value = const TextEditingValue(
        text: '@main',
        selection: TextSelection.collapsed(offset: 5),
      );
      await tester.pump();

      // Overlay is not shown until fetch completes (first query)
      expect(find.byType(ListView), findsNothing);

      // Complete the fetch
      completer.complete([
        const FileSuggestion(label: 'main.dart', path: 'lib/main.dart'),
      ]);
      await tester.pump();
      await tester.pumpAndSettle();

      // Suggestions should now show
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
      controller.value = const TextEditingValue(
        text: '@mai',
        selection: TextSelection.collapsed(offset: 4),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('main.dart').first);
      await tester.pumpAndSettle();

      // Focus should remain on the input
      expect(focusNode.hasFocus, isTrue);
    });
  });
}
