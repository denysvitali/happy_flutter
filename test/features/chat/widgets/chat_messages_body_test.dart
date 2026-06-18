import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/widgets/chat_loading_shimmer.dart';
import 'package:happy_flutter/features/chat/widgets/chat_messages_body.dart';
import 'package:happy_flutter/features/chat/widgets/empty_chat_view.dart';
import 'package:happy_flutter/features/chat/widgets/retry_error_view.dart';

Widget _wrap({
  required bool isLoading,
  required List<int> messages,
  required bool loadFailed,
  VoidCallback? onRetry,
  ValueChanged<String>? onSuggestionTap,
  Widget messageList = const SizedBox(key: ValueKey('message-list')),
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChatMessagesBody(
        isLoading: isLoading,
        messages: messages,
        loadFailed: loadFailed,
        onRetry: onRetry ?? () {},
        onSuggestionTap: onSuggestionTap ?? (_) {},
        messageList: messageList,
      ),
    ),
  );
}

void main() {
  group('ChatMessagesBody', () {
    testWidgets('shows the loading shimmer when isLoading is true', (tester) async {
      await tester.pumpWidget(_wrap(
        isLoading: true,
        messages: const [],
        loadFailed: false,
      ));
      expect(find.byType(ChatLoadingShimmer), findsOneWidget);
    });

    testWidgets('shows the retry view when loadFailed and messages is empty',
        (tester) async {
      await tester.pumpWidget(_wrap(
        isLoading: false,
        messages: const [],
        loadFailed: true,
      ));
      expect(find.byType(RetryErrorView), findsOneWidget);
      expect(find.byType(EmptyChatView), findsNothing);
      expect(find.byType(ChatLoadingShimmer), findsNothing);
    });

    testWidgets('shows the empty view when not loading, not failed, empty',
        (tester) async {
      var suggestionTaps = 0;
      await tester.pumpWidget(_wrap(
        isLoading: false,
        messages: const [],
        loadFailed: false,
        onSuggestionTap: (_) => suggestionTaps++,
      ));
      expect(find.byType(EmptyChatView), findsOneWidget);
      expect(find.byType(RetryErrorView), findsNothing);
      expect(find.byType(ChatLoadingShimmer), findsNothing);
    });

    testWidgets('shows the message list when not loading and messages non-empty',
        (tester) async {
      const list = SizedBox(key: ValueKey('message-list'));
      await tester.pumpWidget(_wrap(
        isLoading: false,
        messages: const [1, 2, 3],
        loadFailed: false,
        messageList: list,
      ));
      expect(find.byWidget(list), findsOneWidget);
      expect(find.byType(EmptyChatView), findsNothing);
      expect(find.byType(RetryErrorView), findsNothing);
      expect(find.byType(ChatLoadingShimmer), findsNothing);
    });

    testWidgets('isLoading takes precedence over loadFailed and empty',
        (tester) async {
      // When loading, we don't care about other state — the shimmer is
      // always shown.
      await tester.pumpWidget(_wrap(
        isLoading: true,
        messages: const [],
        loadFailed: true,
      ));
      expect(find.byType(ChatLoadingShimmer), findsOneWidget);
      expect(find.byType(RetryErrorView), findsNothing);
    });

    testWidgets('loadFailed takes precedence over empty when messages is empty',
        (tester) async {
      // When loadFailed is true, we show the retry view (not the
      // empty state) even if messages is empty.
      var retryTaps = 0;
      await tester.pumpWidget(_wrap(
        isLoading: false,
        messages: const [],
        loadFailed: true,
        onRetry: () => retryTaps++,
      ));
      expect(find.byType(RetryErrorView), findsOneWidget);
      expect(find.byType(EmptyChatView), findsNothing);
    });
  });
}
