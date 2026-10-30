import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/core/models/outgoing_image.dart';
import 'package:happy_flutter/core/providers/app_providers.dart';
import 'package:happy_flutter/core/services/offline_dictation_service.dart';
import 'package:happy_flutter/core/services/draft_storage.dart';
import 'package:happy_flutter/core/services/mmkv_storage.dart';
import 'package:happy_flutter/core/theme/app_tokens.dart';
import 'package:happy_flutter/features/chat/chat_input.dart';
import 'package:happy_flutter/features/chat/send/chat_attachment_controller.dart';
import 'package:happy_flutter/features/chat/widgets/autocomplete_overlay.dart';
import 'package:happy_flutter/features/chat/widgets/chat_input_buttons.dart';
import 'package:happy_flutter/features/chat/widgets/file_autocomplete.dart';
import 'package:happy_flutter/features/chat/widgets/input_toolbar.dart';

Widget _buildComposer({
  required TextEditingController controller,
  required VoidCallback onSend,
  String sessionId = 'composer-test',
  VoidCallback? onQueueNextTurn,
  ChatAttachmentController? attachmentController,
  FileSuggestionsLoader? onFileSuggestionsRequested,
  MediaQueryData? mediaQueryData,
  OfflineDictationService? dictationService,
  String? sessionFlavor,
}) {
  final composer = Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: ChatInput(
        sessionId: sessionId,
        controller: controller,
        attachmentController: attachmentController,
        onSend: onSend,
        onQueueNextTurn: onQueueNextTurn,
        onFileSuggestionsRequested: onFileSuggestionsRequested,
        sessionFlavor: sessionFlavor,
      ),
    ),
  );

  return ProviderScope(
    overrides: [
      if (dictationService != null)
        offlineDictationServiceProvider.overrideWithValue(dictationService),
    ],
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

  setUp(() async {
    await DraftStorage().removeDraft('composer-test');
  });

  for (final delayed in [false, true]) {
    testWidgets(
      'dictation disposal cancels ${delayed ? 'late start' : 'capture'}',
      (tester) async {
        final controller = TextEditingController();
        final service = _FakeDictationService(delayed: delayed);
        await tester.pumpWidget(
          _buildComposer(
            controller: controller,
            onSend: () {},
            dictationService: service,
          ),
        );
        await tester.tap(find.byIcon(Icons.mic_none_rounded));
        await tester.pump();
        if (!delayed) expect(service.recording, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        if (delayed) service.startBarrier.complete();
        await tester.pump();
        await tester.pump();
        expect(service.recording, isFalse);
        expect(service.cancels, greaterThanOrEqualTo(1));
        service.transcript?.call('late transcript');
        expect(controller.text, isEmpty);
        expect(tester.takeException(), isNull);
        controller.dispose();
        await service.dispose();
      },
    );
  }

  testWidgets('disposing an idle composer cannot cancel another owner', (
    tester,
  ) async {
    final first = TextEditingController();
    final second = TextEditingController();
    final service = _FakeDictationService();
    Widget composers(bool showSecond) => ProviderScope(
      overrides: [offlineDictationServiceProvider.overrideWithValue(service)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              ChatInput(
                key: const ValueKey('owner'),
                sessionId: 'composer-test',
                controller: first,
                onSend: () {},
              ),
              if (showSecond)
                ChatInput(
                  key: const ValueKey('idle'),
                  sessionId: 'composer-other',
                  controller: second,
                  onSend: () {},
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(composers(true));
    await tester.tap(find.byIcon(Icons.mic_none_rounded).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    await tester.pumpWidget(composers(false));
    await tester.pump();
    expect(service.recording, isTrue);
    expect(service.cancels, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(service.recording, isFalse);
    first.dispose();
    second.dispose();
    await service.dispose();
  });

  testWidgets('dictation handoff waits for the canceled stop to settle', (
    tester,
  ) async {
    final controller = TextEditingController();
    final service = _FakeDictationService();
    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () {},
        dictationService: service,
      ),
    );
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();
    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        sessionId: 'composer-next-session',
        onSend: () {},
        dictationService: service,
      ),
    );
    await tester.pump();
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    expect(service.starts, 1);
    service.stopBarrier.complete('old transcript');
    await tester.pump();
    await tester.pump();
    expect(controller.text, isEmpty);
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    expect(service.starts, 2);
    expect(service.recording, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
    await service.dispose();
  });

  testWidgets('dictation cancels when composer changes session', (
    tester,
  ) async {
    final controller = TextEditingController();
    final service = _FakeDictationService();
    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () {},
        dictationService: service,
      ),
    );
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();
    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        sessionId: 'composer-next-session',
        onSend: () {},
        dictationService: service,
      ),
    );
    await tester.pump();
    expect(service.recording, isFalse);
    service.transcript?.call('outgoing session transcript');
    expect(controller.text, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await service.dispose();
  });

  testWidgets('persists the first edit without requiring another keystroke', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _buildComposer(controller: controller, onSend: () {}),
    );

    await tester.enterText(find.byType(TextField), 'Pasted draft');
    await tester.pump();
    expect(await DraftStorage().getDraft('composer-test'), 'Pasted draft');

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('flushes pending draft edits when leaving the composer', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _buildComposer(controller: controller, onSend: () {}),
    );

    await tester.enterText(find.byType(TextField), 'Initial draft');
    await tester.enterText(find.byType(TextField), 'Updated draft');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(await DraftStorage().getDraft('composer-test'), 'Updated draft');
    final persisted =
        jsonDecode(MMKVStorage().getString('session-drafts')!)
            as Map<String, dynamic>;
    expect(persisted['composer-test'], 'Updated draft');
    controller.dispose();
  });

  testWidgets('keeps pending drafts with their session on controller swaps', (
    tester,
  ) async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    await DraftStorage().removeDraft('composer-next-session');
    await tester.pumpWidget(
      _buildComposer(controller: oldController, onSend: () {}),
    );
    await tester.enterText(find.byType(TextField), 'Old draft');
    await tester.enterText(find.byType(TextField), 'Old pending draft');

    await tester.pumpWidget(
      _buildComposer(
        sessionId: 'composer-next-session',
        controller: newController,
        onSend: () {},
      ),
    );
    await tester.pump();
    expect(await DraftStorage().getDraft('composer-test'), 'Old pending draft');
    expect(newController.text, isEmpty);

    await tester.enterText(find.byType(TextField), 'New draft');
    await tester.pump();
    expect(await DraftStorage().getDraft('composer-next-session'), 'New draft');
    oldController.text = 'Detached edit';
    await tester.pump(const Duration(milliseconds: 600));
    expect(await DraftStorage().getDraft('composer-test'), 'Old pending draft');
    expect(await DraftStorage().getDraft('composer-next-session'), 'New draft');

    await tester.pumpWidget(const SizedBox.shrink());
    oldController.dispose();
    newController.dispose();
  });

  testWidgets('restores the destination draft when reusing a controller', (
    tester,
  ) async {
    final controller = TextEditingController();
    await DraftStorage().saveDraft('composer-next-session', 'Saved next draft');
    await tester.pumpWidget(
      _buildComposer(controller: controller, onSend: () {}),
    );
    await tester.enterText(find.byType(TextField), 'Outgoing draft');
    await tester.enterText(find.byType(TextField), 'Outgoing pending draft');

    await tester.pumpWidget(
      _buildComposer(
        sessionId: 'composer-next-session',
        controller: controller,
        onSend: () {},
      ),
    );
    await tester.pump();
    expect(controller.text, 'Saved next draft');
    expect(
      await DraftStorage().getDraft('composer-test'),
      'Outgoing pending draft',
    );

    await tester.enterText(find.byType(TextField), 'Next edited draft');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(
      await DraftStorage().getDraft('composer-next-session'),
      'Next edited draft',
    );
    expect(
      await DraftStorage().getDraft('composer-test'),
      'Outgoing pending draft',
    );
    controller.dispose();
  });

  testWidgets('preserves an explicitly supplied controller draft on switch', (
    tester,
  ) async {
    final oldController = TextEditingController();
    final newController = TextEditingController(text: 'Intentional prefill');
    await DraftStorage().saveDraft('composer-next-session', 'Saved draft');
    await tester.pumpWidget(
      _buildComposer(controller: oldController, onSend: () {}),
    );
    await tester.pumpWidget(
      _buildComposer(
        sessionId: 'composer-next-session',
        controller: newController,
        onSend: () {},
      ),
    );
    await tester.pump();
    expect(newController.text, 'Intentional prefill');

    await tester.pumpWidget(const SizedBox.shrink());
    oldController.dispose();
    newController.dispose();
  });

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

    // An empty draft offers dictation instead of a dead send button.
    expect(find.byType(SendButton), findsNothing);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    expect(sends, 0);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(find.byType(SendButton), findsNothing);

    await tester.enterText(find.byType(TextField), 'Review this change');
    await tester.pump();
    expect(sendNode(), isSemantics(hasEnabledState: true, isEnabled: true));

    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);

    await tester.tap(find.byType(SendButton));
    await tester.pump();
    expect(sends, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
    controller.dispose();
  });

  testWidgets('send appears with a draft and hides again when cleared', (
    tester,
  ) async {
    final controller = TextEditingController();
    final inputRow = find.byKey(
      const ValueKey<String>('chat-composer-input-row'),
    );

    await tester.pumpWidget(
      _buildComposer(controller: controller, onSend: () {}),
    );
    await tester.pump();
    expect(find.byType(SendButton), findsNothing);
    expect(
      find.descendant(
        of: inputRow,
        matching: find.byIcon(Icons.mic_none_rounded),
      ),
      findsOneWidget,
    );

    controller.text = 'Ship it';
    await tester.pump();
    // Send lives inside the field row, replacing the mic.
    expect(
      find.descendant(of: inputRow, matching: find.byType(SendButton)),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);

    controller.clear();
    await tester.pump();
    expect(find.byType(SendButton), findsNothing);
    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
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

    expect(find.byType(SendButton), findsNothing);

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

  testWidgets('offers a distinct next-turn action for active Codex turns', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final controller = TextEditingController(text: 'Handle this next');
    var sends = 0;
    var queued = 0;

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () => sends++,
        onQueueNextTurn: () => queued++,
      ),
    );
    await tester.pump();

    final queueButton = find.byKey(
      const ValueKey<String>('queue-next-turn-button'),
    );
    final inputRow = find.byKey(
      const ValueKey<String>('chat-composer-input-row'),
    );
    final toolbar = find.byKey(const ValueKey<String>('chat-composer-toolbar'));
    expect(queueButton, findsOneWidget);
    expect(inputRow, findsOneWidget);
    expect(
      find.descendant(of: inputRow, matching: find.byType(TextField)),
      findsOneWidget,
    );
    // Both follow-up actions sit inside the field row next to the draft;
    // the settings row below never carries send actions.
    expect(find.descendant(of: inputRow, matching: queueButton), findsOne);
    expect(
      find.descendant(of: inputRow, matching: find.byType(SendButton)),
      findsOneWidget,
    );
    expect(find.descendant(of: toolbar, matching: queueButton), findsNothing);
    expect(
      find.descendant(of: toolbar, matching: find.byType(SendButton)),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('chat-follow-up-actions')),
      findsOneWidget,
    );
    expect(
      find.text('Update changes the running turn; Queue starts afterward.'),
      findsNothing,
    );
    expect(
      tester.getSemantics(queueButton),
      isSemantics(
        label: 'Queue for next turn',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(queueButton);
    await tester.pump();
    expect(queued, 1);
    expect(sends, 0);

    await tester.tap(find.byType(SendButton));
    await tester.pump();
    expect(sends, 1);
    expect(
      tester.getSemantics(find.byType(SendButton)),
      isSemantics(
        label: 'Update current turn',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    handle.dispose();
    controller.dispose();
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

  testWidgets('single-line hint is centred on the dictation button', (
    tester,
  ) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      _buildComposer(controller: controller, onSend: () {}),
    );
    await tester.pump();

    final field = find.byType(TextField);
    final mic = find.byIcon(Icons.mic_none_rounded);
    expect(mic, findsOneWidget);
    expect(
      tester.getCenter(field).dy,
      moreOrLessEquals(tester.getCenter(mic).dy, epsilon: 2),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('active-turn actions do not grow the composer', (tester) async {
    final controller = TextEditingController(text: 'A compact follow-up');
    final composerCard = find.byKey(
      const ValueKey<String>('chat-composer-card'),
    );

    await tester.pumpWidget(
      _buildComposer(controller: controller, onSend: () {}),
    );
    await tester.pump();
    final idleHeight = tester.getSize(composerCard).height;

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () {},
        onQueueNextTurn: () {},
      ),
    );
    await tester.pump();

    expect(tester.getSize(composerCard).height, idleHeight);
    expect(find.byType(QueueNextTurnButton), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('empty active-turn composer hides the queue action', (
    tester,
  ) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () {},
        onQueueNextTurn: () {},
      ),
    );
    await tester.pump();
    expect(find.byType(QueueNextTurnButton), findsNothing);
    expect(find.byType(SendButton), findsNothing);

    controller.text = 'now there is text';
    await tester.pump();
    expect(find.byType(QueueNextTurnButton), findsOneWidget);
    expect(find.byType(SendButton), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('keeps the draft and its actions in one rounded field', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Draft');

    await tester.pumpWidget(
      _buildComposer(controller: controller, onSend: () {}),
    );
    await tester.pump();

    final composerCard = find.byKey(
      const ValueKey<String>('chat-composer-card'),
    );
    expect(composerCard, findsOneWidget);
    expect(
      find.descendant(of: composerCard, matching: find.byType(TextField)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: composerCard, matching: find.byType(SendButton)),
      findsOneWidget,
    );
    // Attach/options "+" sits beside the field; approvals and model sit
    // in one settings row underneath it.
    final plus = find.byKey(const ValueKey<String>('composer-attach-button'));
    expect(plus, findsOneWidget);
    expect(find.descendant(of: composerCard, matching: plus), findsNothing);
    expect(
      tester.getCenter(plus).dx,
      lessThan(tester.getTopLeft(composerCard).dx),
    );
    expect(
      find.descendant(of: composerCard, matching: find.byType(InputToolbar)),
      findsNothing,
    );
    expect(find.byType(InputToolbar), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(InputToolbar)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(composerCard).dy),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('names the agent in the placeholder', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () {},
        sessionFlavor: 'claude',
      ),
    );
    await tester.pump();
    expect(find.text('Ask Claude…'), findsOneWidget);

    await tester.pumpWidget(
      _buildComposer(controller: controller, onSend: () {}),
    );
    await tester.pump();
    expect(find.text('Ask your agent…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('the + sheet offers attachments, model and the full editor', (
    tester,
  ) async {
    final controller = TextEditingController();
    final attachments = ChatAttachmentController();

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        attachmentController: attachments,
        onSend: () {},
      ),
    );
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey<String>('composer-attach-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add to message'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('composer-sheet-model')), findsOneWidget);
    expect(find.text('Open full editor'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    attachments.dispose();
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

  testWidgets('keeps active-turn choices stable on a narrow large-text view', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final controller = TextEditingController(text: 'Continue with this');

    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () {},
        onQueueNextTurn: () {},
        mediaQueryData: const MediaQueryData(textScaler: TextScaler.linear(2)),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(SendButton), findsOneWidget);
    expect(find.byType(QueueNextTurnButton), findsOneWidget);

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

  testWidgets('completes the whole file token when the cursor is inside it', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      _buildComposer(
        controller: controller,
        onSend: () {},
        onFileSuggestionsRequested: (_) async => [
          AutocompleteSuggestion(
            id: 'lib/main.dart',
            label: 'lib/main.dart',
            type: SuggestionType.file,
          ),
        ],
      ),
    );
    await tester.enterText(find.byType(TextField), '@lib/mai.dart details');
    controller.selection = const TextSelection.collapsed(offset: 8);
    await tester.pump(const Duration(milliseconds: 101));
    await tester.pump();
    await tester.tap(find.text('lib/main.dart'));
    await tester.pump();

    expect(controller.text, '@lib/main.dart details');
    expect(controller.selection.baseOffset, '@lib/main.dart '.length);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

class _FakeDictationService implements OfflineDictationService {
  _FakeDictationService({this.delayed = false});
  final bool delayed;
  final _progress = ValueNotifier<Map<String, OfflineSttDownloadProgress>>(
    const {},
  );
  final startBarrier = Completer<void>();
  bool recording = false;
  int cancels = 0;
  int starts = 0;
  final stopBarrier = Completer<String>();
  void Function(String)? transcript;

  @override
  OfflineSttModel get selectedModel => OfflineSttCatalog.defaultModel;

  @override
  String get selectedModelId => OfflineSttCatalog.defaultModel.id;

  @override
  ValueNotifier<Map<String, OfflineSttDownloadProgress>> get progress =>
      _progress;

  @override
  OfflineSttStatus statusFor(String modelId) => OfflineSttStatus.ready;

  @override
  Future<void> start({
    void Function(String)? onTranscript,
    bool Function()? shouldContinue,
  }) async {
    starts++;
    transcript = onTranscript;
    if (delayed) await startBarrier.future;
    // Deliberately ignore shouldContinue: cleanup must also handle an
    // already-open recorder whose start completion arrived after disposal.
    recording = true;
  }

  @override
  Future<String> stopAndTranscribe() => stopBarrier.future;

  @override
  Future<void> cancel() async {
    cancels++;
    recording = false;
  }

  @override
  Stream<double> levels({
    Duration interval = const Duration(milliseconds: 200),
  }) => const Stream.empty();

  @override
  Future<void> dispose() async {
    await cancel();
    _progress.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
