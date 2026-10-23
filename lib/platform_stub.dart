// Stub implementations for platforms that lack dart:io (e.g. web).
bool get isAndroid => false;
bool get isIOS => false;
bool get isLinux => false;

String get linuxArchitecture => 'unknown';

/// Web has no process RSS; 0 disables memory sampling.
int get currentRssBytes => 0;

/// Browser APIs do not expose process CPU accounting.
Duration? get currentProcessCpuTime => null;
