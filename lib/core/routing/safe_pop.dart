import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../services/logger_service.dart';

/// Default fallback route for screens whose pop stack is empty.
const String kDefaultFallbackRoute = 'sessions';

/// Safely pop the current route, falling back to a named route if the
/// local navigator has nothing to pop.
///
/// This guards against the production back-button error rate spike where
/// a deep-linked screen calls [GoRouter.pop] on an empty stack and the
/// router throws. The standard fix is:
///
/// 1. Check [BuildContext.canPop] first.
/// 2. Otherwise [GoRouter.goNamed] to a sensible fallback (defaults to
///    `sessions`).
/// 3. Swallow any residual exception, log it, and stay on-screen rather
///    than letting it bubble to the GlitchTip / Sentry transaction.
///
/// Callers that need to confirm the navigation succeeded can inspect the
/// returned [bool]: `true` if a pop happened, `false` if the fallback
/// route was used or if the call was a no-op due to an unmounted context.
bool safePop<T extends Object?>(
  BuildContext context, {
  T? result,
  String fallbackRouteName = kDefaultFallbackRoute,
  Map<String, String> fallbackPathParameters = const {},
}) {
  // Unmounted contexts must never be used for navigation. Callers that
  // forget the `if (!mounted) return;` guard after an `await` would
  // otherwise crash here.
  if (!context.mounted) return false;

  try {
    if (context.canPop()) {
      context.pop(result);
      return true;
    }
    context.goNamed(
      fallbackRouteName,
      pathParameters: fallbackPathParameters,
    );
    return false;
  } catch (e, st) {
    logger.warning(
      '[safePop] navigation failed; staying on screen: $e',
      e,
      st,
    );
    return false;
  }
}
