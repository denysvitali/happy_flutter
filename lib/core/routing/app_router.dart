import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/artifacts/artifact_detail_screen.dart';
import '../../features/artifacts/artifacts_list_screen.dart';
import '../../features/artifacts/edit_artifact_screen.dart';
import '../../features/artifacts/new_artifact_screen.dart';
import '../../features/changelog/changelog_screen.dart';
import '../../features/chat/agent_conversation_screen.dart';
import '../../features/chat/chat_screen.dart';
import '../../features/chat/message_detail_screen.dart';
import '../../features/chat/session_file_viewer_screen.dart';
import '../../features/chat/session_files_screen.dart';
import '../../features/chat/session_info_screen.dart';
import '../../features/chat/session_recent_screen.dart';
import '../../features/dev/dev_logs_screen.dart';
import '../../features/loops/goal_loops_screen.dart';
import '../../features/loops/loops_screen.dart';
import '../../features/dev/encryption_debug_screen.dart';
import '../../features/dev/network_inspector_screen.dart';
import '../../features/dev/notification_test_screen.dart';
import '../../features/dev/power_diagnostics_screen.dart';
import '../../features/dev/session_debug_screen.dart';
import '../../features/machine/machine_detail_screen.dart';
import '../../features/mcp/mcp_server_edit_screen.dart';
import '../../features/mcp/mcp_servers_screen.dart';
import '../../features/sandbox/sandbox_screen.dart';
import '../../features/sessions/sessions_screen.dart';
import '../../features/settings/account_screen.dart';
import '../../features/settings/claude_limits_screen.dart';
import '../../features/settings/codex_usage_screen.dart';
import '../../features/settings/developer_screen.dart';
import '../../features/settings/features_settings_screen.dart';
import '../../features/settings/grok_usage_screen.dart';
import '../../features/settings/link_device_screen.dart';
import '../../features/settings/linked_devices_screen.dart';
import '../../features/settings/machines_screen.dart';
import '../../features/settings/offline_stt_models_screen.dart';
import '../../features/settings/offline_voices_screen.dart';
import '../../features/settings/profile_editor_screen.dart';
import '../../features/settings/profile_wizard_screen.dart';
import '../../features/settings/profiles_screen.dart';
import '../../features/settings/restore_account_screen.dart';
import '../../features/settings/screens/auto_archive_settings_screen.dart';
import '../../features/settings/screens/sessions_folders_settings_screen.dart';
import '../../features/settings/server_settings_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/theme_settings_screen.dart';
import '../../features/settings/usage_screen.dart';
import '../../features/settings/voice_language_settings_screen.dart';
import '../../features/settings/voice_settings_screen.dart';
import '../../features/terminal/terminal_connect_screen.dart';
import '../../features/terminal/terminal_screen.dart';
import '../../features/workflows/workflow_run_screen.dart';
import '../../features/workflows/workflows_screen.dart';
import '../../features/zen/views/zen_home.dart';
import '../../sentry_widget.dart'
    if (dart.library.js_interop) '../../sentry_widget_stub.dart';
import '../models/auth.dart';
import '../models/settings.dart';
import '../providers/app_providers.dart';
import '../services/logger_service.dart';
import '../services/opentelemetry_service.dart';
import '../services/performance_context_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/auth_gate.dart';

part 'routes/_shell_routes.dart';
part 'routes/_settings_routes.dart';
part 'routes/_chat_routes.dart';
part 'routes/_feature_routes.dart';

/// Fade-through transition for tab-level routes: the incoming screen
/// fades in while settling from a subtle 98 % scale, giving tab
/// switches a sense of depth instead of a flat crossfade.
Page<void> _fadePage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: _routeName(state),
    arguments: state.extra,
    restorationId: state.pageKey.value,
    child: child,
    transitionsBuilder: (context, animation, _, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final eased = CurvedAnimation(parent: animation, curve: AppCurve.enter);
      return FadeTransition(
        opacity: eased,
        child: ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.0).animate(eased),
          child: child,
        ),
      );
    },
    transitionDuration: AppDuration.fast,
    reverseTransitionDuration: AppDuration.fast,
  );
}

/// Slide-up transition for creation / modal flows.
Page<void> _slideUpPage(Widget child, GoRouterState state) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    name: _routeName(state),
    arguments: state.extra,
    restorationId: state.pageKey.value,
    child: child,
    transitionsBuilder: (context, animation, _, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final tween = Tween(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: AppCurve.enter),
        child: SlideTransition(position: animation.drive(tween), child: child),
      );
    },
    transitionDuration: AppDuration.slow,
    reverseTransitionDuration: AppDuration.normal,
  );
}

/// Slide-in transition for detail/push screens with swipe-back
/// gesture support via [_SwipeBackPage].
Page<void> _slidePage(Widget child, GoRouterState state) {
  return _SwipeBackPage(
    key: state.pageKey,
    name: _routeName(state),
    arguments: state.extra,
    restorationId: state.pageKey.value,
    child: child,
  );
}

String _routeName(GoRouterState state) {
  return state.name ?? state.fullPath ?? state.matchedLocation;
}

/// A [Page] that slides in from the right and supports iOS-style
/// swipe-back gesture on all platforms.
class _SwipeBackPage extends Page<void> {
  const _SwipeBackPage({
    required this.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) {
    return _SwipeBackRoute(
      page: this,
      animationsDisabled: MediaQuery.disableAnimationsOf(context),
    );
  }
}

class _SwipeBackRoute extends PageRoute<void> {
  _SwipeBackRoute({
    required _SwipeBackPage page,
    required this.animationsDisabled,
  }) : super(settings: page);

  final bool animationsDisabled;

  _SwipeBackPage get _page => settings as _SwipeBackPage;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration =>
      animationsDisabled ? Duration.zero : const Duration(milliseconds: 300);

  @override
  Duration get reverseTransitionDuration =>
      animationsDisabled ? Duration.zero : const Duration(milliseconds: 250);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _page.child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (animationsDisabled) return child;
    if (kIsWeb) {
      return CupertinoPageTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: false,
        child: child,
      );
    }

    return CupertinoRouteTransitionMixin.buildPageTransitions<void>(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Creates the [GoRouter] instance for the app.
///
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    observers: [
      SentryNavigatorObserver(),
      PerformanceRouteObserver(),
      OpenTelemetryService().routeObserver,
    ],
    routes: [
      ...shellRoutes,
      ...settingsRoutes,
      ...chatRoutes,
      ...featureRoutes,
    ],
    redirect: (context, state) {
      final authState = ProviderScope.containerOf(
        context,
      ).read(authStateNotifierProvider);
      if (state.matchedLocation == '/') {
        if (authState == AuthState.authenticated) {
          return '/sessions';
        }
        return null;
      }
      return null;
    },
  );
}

String? _pathParameter(GoRouterState state, String name) {
  final value = state.pathParameters[name];
  if (value != null && value.isNotEmpty) return value;
  logger.warning(
    '[router] missing path parameter "$name" for '
    'location=${state.uri}',
  );
  return null;
}

Page<void> _missingPathParameterPage(GoRouterState state, String name) {
  return _slidePage(
    Scaffold(body: Center(child: Text('Missing route parameter: $name'))),
    state,
  );
}
