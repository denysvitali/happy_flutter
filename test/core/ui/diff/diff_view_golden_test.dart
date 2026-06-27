import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/ui/diff/unified_diff_view.dart';
import 'package:happy_flutter/core/utils/theme_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const oldText = '''import 'package:flutter/material.dart';

class Greeter {
  String name;

  Greeter(this.name);

  String greet() {
    return 'Hello, ' + name + '!';
  }

  void debug() {
    print('greeting for \$name');
  }
}
''';

  const newText = '''import 'package:flutter/material.dart';

class Greeter {
  final String name;

  const Greeter(this.name);

  String greet() {
    return "Hello, \$name!";
  }

  void debug() {
    // print('greeting for \$name');
  }
}
''';

  Widget buildDiff({required bool dark}) {
    return MaterialApp(
      theme: dark
          ? ThemeHelper.buildDarkTheme()
          : ThemeHelper.buildLightTheme(),
      darkTheme: ThemeHelper.buildDarkTheme(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: UnifiedDiffView(
              oldText: oldText,
              newText: newText,
              contextLines: 3,
              showLineNumbers: true,
              showPlusMinusSymbols: true,
              showDiffStats: true,
            ),
          ),
        ),
      ),
    );
  }

  group('UnifiedDiffView golden', () {
    testWidgets('renders a unified diff in light mode', (tester) async {
      tester.view.physicalSize = const Size(600 * 2, 1500 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildDiff(dark: false));
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/unified_diff_light.png'),
      );
    });

    testWidgets('renders a unified diff in dark mode', (tester) async {
      tester.view.physicalSize = const Size(600 * 2, 1500 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildDiff(dark: true));
      await tester.pump(const Duration(milliseconds: 200));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/unified_diff_dark.png'),
      );
    });
  });
}
