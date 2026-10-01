import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the one-implementation-per-element rule from eroding: each pattern
/// below was consolidated once and must not come back as a parallel copy.
///
/// If a legitimate exception appears, add the file to that rule's allowlist
/// with a reason rather than loosening the pattern.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where((f) => !f.path.endsWith('.g.dart'))
      .where((f) => !f.path.contains('l10n_generated'))
      .toList();

  List<String> offenders(RegExp pattern, {Set<String> allow = const {}}) {
    final out = <String>[];
    for (final f in files) {
      if (allow.any(f.path.contains)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (pattern.hasMatch(line)) out.add('${f.path}:${i + 1}');
      }
    }
    return out;
  }

  void expectNone(String rule, RegExp pattern, {Set<String> allow = const {}}) {
    test(rule, () {
      expect(
        offenders(pattern, allow: allow),
        isEmpty,
        reason: 'Found parallel implementations — $rule',
      );
    });
  }

  expectNone(
    'buttons: use FilledButton (themed), not ElevatedButton',
    RegExp(r'\bElevatedButton\b'),
    // The theme keeps a style for stock widgets that pull one in.
    allow: {'theme_helper.dart'},
  );

  expectNone(
    'type scale: no literal fontSize, use AppFontSize or a textTheme slot',
    RegExp(r'fontSize:\s*[0-9]'),
    allow: {
      'theme_helper.dart', // defines the scale
      'app_typography.dart', // legacy mirror of the scale
      // 8sp numeral inside a 14dp running-count dot; 12sp cannot fit.
      'chat_app_bar.dart',
    },
  );

  expectNone(
    'type scale: AppFontSize.xxs/xs were removed, use sm',
    RegExp(r'AppFontSize\.(xxs|xs)\b'),
  );

  expectNone(
    'progress: use the App* progress wrappers, not the raw widgets',
    RegExp(
      r'(?<![A-Za-z])(CircularProgressIndicator|LinearProgressIndicator)\(',
    ),
    allow: {
      'app_circular_progress_indicator.dart',
      'app_linear_progress_indicator.dart',
    },
  );

  expectNone(
    'destructive buttons: use AppButtonStyle, not styleFrom(foreground: error)',
    RegExp(
      r'styleFrom\(\s*(foregroundColor|backgroundColor):\s*[\w.()]*\.error\b',
    ),
  );

  expectNone(
    'control sizes: use AppControlSize, not 28/30/32/36/40 literals',
    RegExp(r'\b(width|height|dimension):\s*(28|30|32|36|40),'),
    allow: {
      // Drag handle width in a sheet, not a control.
      'app_sheet.dart',
    },
  );

  expectNone(
    'row text: use an AppText role, not textTheme.xxx?.copyWith overrides',
    RegExp(
      r'\.textTheme\.(titleSmall|bodySmall|labelSmall|labelMedium)\?\.copyWith\(',
    ),
    allow: {
      'theme_helper.dart',
      'app_text.dart',
      'app_typography.dart',
      // Transcript tool views and dev screens are dense, one-off layouts.
      'features/dev/',
      'chat/tools/',
      'chat/markdown/',
      // These take a TextTheme parameter rather than a BuildContext.
      'session_cards.dart',
      'chat_app_bar.dart',
      'tts_playback_bar.dart',
      'server_url_dialog.dart',
      'profile_editor_row_state.dart',
      'session_recent_screen.dart',
      'session_info_widgets.dart',
      'permission_mode_selector.dart',
    },
  );
}
