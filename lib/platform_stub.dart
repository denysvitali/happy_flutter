// Stub implementations for platforms that lack dart:io (e.g. web).
bool get isAndroid => false;
bool get isIOS => false;
bool get isLinux => false;

/// Web has no process RSS; 0 disables memory sampling.
int get currentRssBytes => 0;
