import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/outgoing_image.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/features/chat/chat_input.dart';
import 'package:happy_flutter/features/chat/send/chat_attachment_controller.dart';
import 'package:happy_flutter/features/chat/widgets/autocomplete_overlay.dart';
import 'package:happy_flutter/features/chat/widgets/chat_input_buttons.dart';
import 'package:happy_flutter/features/chat/widgets/file_autocomplete.dart';

Widget _buildComposer({
  required TextEditingController controller,
  required VoidCallback onSend,
  ChatAttachmentController? attachmentController,
  FileSuggestionsLoader? onFileSuggestionsRequested,
  MediaQueryData? mediaQueryData,
}) {
  final composer = Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: ChatInput(
        sessionId: 'composer-test',
        controller: controller,
        attachmentController: attachmentController,
        onSend: onSend,
        onFileSuggestionsRequested: onFileSuggestionsRequested,
      ),
    ),
  );

  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: mediaQueryData == null
          ? composer
          : MediaQuery(data: mediaQueryData, child: composer),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('only enables send for meaningful draft content', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = TextEditingController();
    var sends = 0;

    await tester.pumpWidget(
      _buildComposer(controller: controller, onSend: () => sends++),
    );
    await tester.pump();

    SemanticsNode sendNode() {
      return tester.getSemantics(find.byType(SendButton));
    }

    expect(sendNode(), isSemantics(hasEnabledState: true, isEnabled: false));
    await tester.tap(find.byType(SendButton));
    expect(sends, 0);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(sendNode(), isSemantics(hasEnabledState: true, isEnabled: false));

    await tester.enterText(find.byType(TextField), 'Review this change');
    await tester.pump();
    expect(sendNode(), isSemantics(hasEnabledState: true, isEnabled: true));

    await tester.tap(find.byType(SendButton));
    await tester.pump();
    expect(sends, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
    controller.dispose();
  });

  testWidgets('an attachment is sendable without text', (tester) async {
    final handle = tester.ensureSemantics();
    final controller = TextEditingController();
    final attachments = ChatAttachmentController();
    var sends = 0;

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        attachmentController: attachments,
        onSend: () => sends++,
      ),
    );
    await tester.pump();

    expect(
      tester.getSemantics(find.byType(SendButton)),
      isSemantics(hasEnabledState: true, isEnabled: false),
    );

    attachments.add(
      const OutgoingImage(
        mediaType: 'image/png',
        base64Data:
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR'
            '42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        width: 1,
        height: 1,
      ),
    );
    await tester.pump();

    expect(
      tester.getSemantics(find.byType(SendButton)),
      isSemantics(hasEnabledState: true, isEnabled: true),
    );
    await tester.tap(find.byType(SendButton));
    await tester.pump();
    expect(sends, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
    controller.dispose();
    attachments.dispose();
  });

  testWidgets('centers a bounded composer on tablet without live blur', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = TextEditingController();

    await tester.pumpWidget(
      _buildComposer(controller: controller, onSend: () {}),
    );
    await tester.pump();

    final contentSize = tester.getSize(
      find.byKey(const ValueKey<String>('chat-composer-content')),
    );
    expect(contentSize.width, AppBreakpoint.contentMax);
    expect(find.byType(BackdropFilter), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('keeps the composer stable with large text', (tester) async {
    final controller = TextEditingController(text: 'A longer draft');

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () {},
        mediaQueryData: const MediaQueryData(textScaler: TextScaler.linear(2)),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SendButton), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('shows async file suggestions and inserts the selected path', (
    tester,
  ) async {
    final controller = TextEditingController();
    final request = Completer<List<AutocompleteSuggestion>>();
    final queries = <String>[];

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () {},
        onFileSuggestionsRequested: (query) {
          queries.add(query);
          return request.future;
        },
      ),
    );

    await tester.enterText(find.byType(TextField), '@lib/mai');
    await tester.pump(const Duration(milliseconds: 101));
    expect(queries, ['lib/mai']);
    expect(find.byType(FileAutocomplete), findsNothing);

    request.complete([
      AutocompleteSuggestion(
        id: 'lib/main.dart',
        label: 'lib/main.dart',
        type: SuggestionType.file,
      ),
    ]);
    await tester.pump();

    expect(find.byType(FileAutocomplete), findsOneWidget);
    expect(find.text('lib/main.dart'), findsOneWidget);
    await tester.tap(find.text('lib/main.dart'));
    await tester.pump();
    expect(controller.text, '@lib/main.dart ');

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
