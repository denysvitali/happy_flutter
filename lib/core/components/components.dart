/// Shared UI component library for Happy Flutter.
///
/// Layer rule:
/// - `theme/` — tokens only
/// - `ui/` — dumb primitives (no Riverpod)
/// - `components/` — product design system (`App*`)
/// - `widgets/` — app-shell only (auth, offline, sync, error boundary)
/// - `features/` — compose only; no new surface shells
///
/// Import this barrel file to access reusable widgets:
/// ```dart
/// import 'package:happy_flutter/core/components/components.dart';
/// ```
library;

export 'package:happy_flutter/core/components/app_badge.dart';
export 'package:happy_flutter/core/components/app_card.dart';
export 'package:happy_flutter/core/components/app_empty_state.dart';
export 'package:happy_flutter/core/components/app_error_state.dart';
export 'package:happy_flutter/core/components/app_loading_indicator.dart';
export 'package:happy_flutter/core/components/app_section_header.dart';
export 'package:happy_flutter/core/components/app_sheet.dart';
export 'package:happy_flutter/core/components/app_status_dot.dart';
export 'package:happy_flutter/core/components/app_tappable.dart';
export 'package:happy_flutter/core/components/avatar.dart';
export 'package:happy_flutter/core/components/exit_code_badge.dart';
export 'package:happy_flutter/core/components/pressable_card.dart';
export 'package:happy_flutter/core/components/scroll_when_bounded.dart';
export 'package:happy_flutter/core/components/settings_section.dart';
export 'package:happy_flutter/core/components/shimmer_view.dart';
export 'package:happy_flutter/core/components/sidebar/app_sidebar.dart';
export 'package:happy_flutter/core/components/sidebar_view.dart';
export 'package:happy_flutter/core/components/tablet/embedded_pane.dart';
export 'package:happy_flutter/core/components/tablet/master_detail_scaffold.dart';
export 'package:happy_flutter/core/components/tablet/resizable_pane_divider.dart';
export 'package:happy_flutter/core/components/task_detail_dialog.dart';
export 'package:happy_flutter/core/components/tool_view_buttons.dart';
export 'package:happy_flutter/core/components/transcription_startup_status_bar.dart';
export 'package:happy_flutter/core/components/voice_assistant_status_bar.dart';
