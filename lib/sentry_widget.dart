import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart' as sentry;

import 'sentry_config.dart';

class SentryWidget extends StatelessWidget {
  const SentryWidget({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!sentryEnabled) return child;
    return sentry.SentryWidget(child: child);
  }
}

class SentryNavigatorObserver extends sentry.SentryNavigatorObserver {
  SentryNavigatorObserver();
}
