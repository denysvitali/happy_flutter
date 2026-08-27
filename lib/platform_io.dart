import 'dart:io' show Platform, ProcessInfo;

bool get isAndroid => Platform.isAndroid;
bool get isIOS => Platform.isIOS;
bool get isLinux => Platform.isLinux;

/// Resident set size of this process in bytes, or 0 when unavailable.
int get currentRssBytes {
  try {
    return ProcessInfo.currentRss;
  } catch (_) {
    // Some platforms (or restricted sandboxes) do not expose RSS.
    return 0;
  }
}
