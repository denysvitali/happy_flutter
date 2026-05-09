/// Feature flag controlling whether the event-sourced message log
/// (item #1 of the architecture overhaul) is consulted on the chat
/// data path.
///
/// When `false` (production default), the existing
/// `_sync_messaging_merge.dart` code path is unchanged.
///
/// When `true`, sync's merge entry point also writes facts into the
/// log and uses [MessageProjection] to build the visible message
/// list.  Tests flip this to `true` via [setUseEventLogForTest].
library;

import 'package:meta/meta.dart';

bool _useEventLog = false;

bool get kUseEventLog => _useEventLog;

@visibleForTesting
void setUseEventLogForTest(bool value) {
  _useEventLog = value;
}
