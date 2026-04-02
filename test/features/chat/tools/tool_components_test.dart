import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/i18n/app_localizations.dart';
import 'package:happy_flutter/features/chat/tools/tool_section_view.dart';
import 'package:happy_flutter/features/chat/tools/tool_status_indicator.dart';
import 'package:happy_flutter/features/chat/tools/tool_error.dart';
import 'package:happy_flutter/features/chat/tools/tool_view_colors.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToolSectionView', () {
    testWidgets('renders with title and children', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolSectionView(
            title: 'Test Section',
            children: [Text('Child 1'), Text('Child 2')],
          ),
        ),
      );

      expect(find.text('TEST SECTION'), findsOneWidget);
      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
    });

    testWidgets('renders with single child', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolSectionView(child: Text('Single Child')),
        ),
      );

      expect(find.text('Single Child'), findsOneWidget);
    });

    testWidgets('renders without title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolSectionView(children: [Text('No Title')]),
        ),
      );

      expect(find.text('No Title'), findsOneWidget);
    });

    testWidgets('title is uppercased', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolSectionView(
            title: 'command',
            children: [SizedBox()],
          ),
        ),
      );

      expect(find.text('COMMAND'), findsOneWidget);
    });

    testWidgets('renders empty children list', (tester) async {
      await tester.pumpWidget(
        _wrap(const ToolSectionView()),
      );

      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('fullWidth applies correct padding', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolSectionView(
            title: 'Full Width',
            fullWidth: true,
            children: [Text('Content')],
          ),
        ),
      );

      expect(find.text('FULL WIDTH'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
    });
  });

  group('ToolStatusIndicator', () {
    testWidgets('renders completed state with check icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolStatusIndicator(state: ToolState.completed),
        ),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('renders error state with cancel icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolStatusIndicator(state: ToolState.error),
        ),
      );

      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    });

    testWidgets('renders pending state with unchecked icon',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolStatusIndicator(state: ToolState.pending),
        ),
      );

      expect(
        find.byIcon(Icons.radio_button_unchecked),
        findsOneWidget,
      );
    });

    testWidgets('renders running state with progress indicator',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolStatusIndicator(state: ToolState.running),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('respects custom size', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolStatusIndicator(
            state: ToolState.completed,
            size: 32,
          ),
        ),
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.check_circle_rounded),
      );
      expect(icon.size, 32);
    });
  });

  group('StatusIcon', () {
    testWidgets('completed shows check icon', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusIcon(state: ToolState.completed)),
      );

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('error shows cancel icon', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusIcon(state: ToolState.error)),
      );

      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    });

    testWidgets('pending shows SizedBox.shrink', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusIcon(state: ToolState.pending)),
      );

      // Pending state renders SizedBox.shrink, no icon visible
      expect(find.byIcon(Icons.radio_button_unchecked), findsNothing);
    });

    testWidgets('running shows pulsing indicator', (tester) async {
      await tester.pumpWidget(
        _wrap(const StatusIcon(state: ToolState.running)),
      );

      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('applies custom color', (tester) async {
      const customColor = Colors.purple;
      await tester.pumpWidget(
        _wrap(
          const StatusIcon(
            state: ToolState.completed,
            color: customColor,
          ),
        ),
      );

      final icon = tester.widget<Icon>(
        find.byIcon(Icons.check_circle_rounded),
      );
      expect(icon.color, customColor);
    });
  });

  group('ToolError', () {
    testWidgets('renders error message', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolError(message: 'Something went wrong'),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('has left border accent', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolError(message: 'Error with border'),
        ),
      );

      final container = tester.widget<Container>(
        find.byType(Container).first,
      );
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.left.width, 3);
    });
  });

  group('ToolResultError', () {
    testWidgets('renders error message', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolResultError(message: 'Result error'),
        ),
      );

      expect(find.text('Result error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('has left border accent', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ToolResultError(message: 'Error'),
        ),
      );

      final containers = tester.widgetList<Container>(find.byType(Container));
      // Find container with border decoration
      final bordered = containers.where((c) {
        final d = c.decoration;
        return d is BoxDecoration && d.border is Border;
      });
      expect(bordered, isNotEmpty);
    });
  });

  group('ToolViewColors', () {
    testWidgets('resolves dark colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(brightness: Brightness.dark),
          home: Builder(
            builder: (context) {
              final colors = ToolViewColors.of(context);
              expect(colors.bg, const Color(0xFF0D1117));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('resolves light colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(brightness: Brightness.light),
          home: Builder(
            builder: (context) {
              final colors = ToolViewColors.of(context);
              expect(colors.bg, const Color(0xFFF6F8FA));
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('has all expected color properties', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final colors = ToolViewColors.of(context);
              // Verify key properties exist and are Colors
              expect(colors.bg, isA<Color>());
              expect(colors.headerBg, isA<Color>());
              expect(colors.border, isA<Color>());
              expect(colors.mutedText, isA<Color>());
              expect(colors.primaryText, isA<Color>());
              expect(colors.green, isA<Color>());
              expect(colors.red, isA<Color>());
              expect(colors.blue, isA<Color>());
              expect(colors.errorText, isA<Color>());
              expect(colors.diffTheme, isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });
}
