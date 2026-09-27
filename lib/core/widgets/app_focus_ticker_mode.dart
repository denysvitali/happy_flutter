import 'package:flutter/widgets.dart';

import '../services/app_visibility_coordinator.dart';

/// Mutes animations when the app loses focus without disposing route state
/// or interrupting the desktop's live message connection.
class AppFocusTickerMode extends StatelessWidget {
  const AppFocusTickerMode({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppFocusState.instance,
    builder: (context, child) =>
        TickerMode(enabled: AppFocusState.instance.isFocused, child: child!),
    child: child,
  );
}
