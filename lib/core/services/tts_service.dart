import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'logger_service.dart' show logger;
import 'offline_tts_service.dart';

enum _Backend { system, offline }

/// Text-to-speech service using the device's built-in TTS engine.
///
/// Strips markdown formatting before speaking so the user hears
/// clean, natural text.
///
/// Exposes [currentToken] as a [ValueListenable] so the chat
/// playback bar can listen for start/stop transitions: callers tag
/// each [speak] with a `token` (typically the message id), and
/// listeners read [currentToken] to render appropriate UI controls.
class TtsService {
  factory TtsService() => _instance;
  TtsService._();
  static final TtsService _instance = TtsService._();

  FlutterTts? _tts;
  bool _initialized = false;
  final ValueNotifier<String?> _currentToken = ValueNotifier<String?>(null);
  final ValueNotifier<String?> _currentText = ValueNotifier<String?>(null);
  bool _offlineListenerAttached = false;
  bool _selfListenerAttached = false;
  _Backend _activeBackend = _Backend.system;
  final List<_QueuedSpeech> _queue = <_QueuedSpeech>[];
  bool _draining = false;
  bool _fallbackLogged = false;

  /// Emit a single info-level breadcrumb per process explaining that
  /// the offline engine is being skipped. We deliberately don't
  /// forward this to Sentry: a fallback to the system TTS engine is
  /// a graceful degradation, not an error, and the original
  /// implementation was capturing it ~once per speak which produced
  /// significant noise (GlitchTip HAPPY_FLUTTER-3C7).
  void _logFallbackOnce(String message) {
    if (_fallbackLogged) return;
    _fallbackLogged = true;
    logger.info(message);
  }

  void _attachOfflineListenerIfNeeded() {
    if (_offlineListenerAttached) return;
    _offlineListenerAttached = true;
    OfflineTtsService().currentToken.addListener(_onOfflineTokenChanged);
  }

  /// Returns `true` when the requested offline [voiceId] (or the
  /// selected one, if unspecified) is not yet known to be `ready`
  /// — used to decide whether to fall back to the system engine
  /// while [OfflineTtsService.initialize] is still running.
  bool _offlineVoiceNotReady(String? voiceId) {
    final id = (voiceId != null && voiceId.isNotEmpty)
        ? voiceId
        : OfflineTtsService().selectedVoiceId;
    if (id.isEmpty) return true;
    return OfflineTtsService().statusFor(id) != OfflineTtsStatus.ready;
  }

  void _attachSelfListenerIfNeeded() {
    if (_selfListenerAttached) return;
    _selfListenerAttached = true;
    _currentToken.addListener(_maybeDrainQueue);
  }

  void _onOfflineTokenChanged() {
    if (_activeBackend != _Backend.offline) return;
    _setCurrentToken(OfflineTtsService().currentToken.value);
    if (OfflineTtsService().currentToken.value == null) {
      _currentText.value = null;
    }
  }

  void _maybeDrainQueue() {
    if (_currentToken.value != null) return;
    if (_queue.isEmpty) return;
    if (_draining) return;
    // Defer to a microtask so the listener returns before we trigger
    // another speak (which may flip the token back and forth).
    Future<void>.microtask(_drainQueue);
  }

  Future<void> _drainQueue() async {
    if (_draining) return;
    if (_currentToken.value != null) return;
    if (_queue.isEmpty) return;
    _draining = true;
    try {
      final next = _queue.removeAt(0);
      await _speakInternal(
        next.markdown,
        token: next.token,
        useOffline: next.useOffline,
        offlineVoiceId: next.offlineVoiceId,
      );
    } finally {
      _draining = false;
    }
  }

  /// Identifier of the speech currently in progress (the token last
  /// passed to [speak]), or `null` when the engine is idle.
  ///
  /// Note: this reflects what the *caller* asked for. The engine
  /// itself fires start/completion events asynchronously; the token
  /// is set when [speak] is invoked and cleared on
  /// completion/cancel/error/stop.
  ValueListenable<String?> get currentToken => _currentToken;

  /// Clean (markdown-stripped) text of the message currently being
  /// spoken, or `null` when the engine is idle. The chat playback bar
  /// uses this to show a one-line preview of what's playing.
  ValueListenable<String?> get currentText => _currentText;

  /// Whether speech is currently in progress.
  bool get isSpeaking => _currentToken.value != null;

  /// Number of speech requests currently waiting in the queue behind
  /// the actively-speaking one. Used by the playback bar to surface a
  /// "+N queued" hint.
  int get queuedCount => _queue.length;

  void _setCurrentToken(String? token) {
    if (_currentToken.value == token) return;
    _currentToken.value = token;
  }

  /// Initialise the TTS engine. Safe to call multiple times.
  Future<void> init({String? language, String? engine}) async {
    if (kIsWeb) return; // TTS not supported on web
    logger.info('[TTS] init called (initialized=$_initialized)');
    // Kick off the offline engine's one-shot bootstrap eagerly so a
    // later user tap on "Speak this message" doesn't race the FFI
    // binding. Fire-and-forget: the system engine init below must
    // not block on a sherpa native probe.
    if (OfflineTtsService().isSupported) {
      unawaited(OfflineTtsService().initialize());
    }
    _tts ??= FlutterTts();
    if (!_initialized) {
      try {
        await _tts!.setSpeechRate(0.5);
        await _tts!.setVolume(1.0);
        await _tts!.setPitch(1.0);
      } catch (e) {
        _tts = null;
        logger.warning('[TTS] init failed: $e');
        return;
      }
      // Configure the audio session *before* the first [speak] so the
      // engine requests `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` on
      // Android (via `speak(..., focus: true)` below) and uses an
      // iOS category that ducks rather than interrupts whatever
      // music/podcast the user is already listening to. Without this,
      // calling [speak] would clobber the user's other audio.
      await _configureAudioSessionForDucking();
      _tts!.setStartHandler(() {
        logger.info('[TTS] Speech started');
      });
      _tts!.setCompletionHandler(() {
        logger.info('[TTS] Speech completed');
        _setCurrentToken(null);
        _currentText.value = null;
      });
      _tts!.setCancelHandler(() {
        logger.info('[TTS] Speech cancelled');
        _setCurrentToken(null);
        _currentText.value = null;
      });
      _tts!.setErrorHandler((msg) {
        logger.error('[TTS] Error: $msg');
        _setCurrentToken(null);
        _currentText.value = null;
      });
      _initialized = true;
      logger.info('[TTS] Engine initialized');
    }
    if (engine != null && engine.isNotEmpty) {
      await _tts!.setEngine(engine);
      logger.info('[TTS] Engine set to $engine');
    }
    if (language != null && language.isNotEmpty) {
      await _tts!.setLanguage(language);
      logger.info('[TTS] Language set to $language');
    }
  }

  /// Configure the underlying TTS audio session so speech ducks other
  /// audio (music, podcasts, navigation) instead of stopping it.
  ///
  /// On Android, [FlutterTts.speak]'s `focus` parameter handles
  /// ducking at speak-time — see [_speakInternal]. There is no global
  /// audio-session configuration to apply here.
  ///
  /// On iOS, the flutter_tts plugin activates the shared
  /// [AVAudioSession] when speech begins and deactivates it with
  /// `.notifyOthersOnDeactivation` when it finishes — but only when
  /// the session's *category options* include `.duckOthers` (see
  /// `shouldDeactivateAndNotifyOthers` in SwiftFlutterTtsPlugin). We
  /// therefore set the category once during [init] to `.playback`
  /// with `[.duckOthers, .mixWithOthers]` and mode `.spokenAudio`,
  /// which is the canonical combination for a turn-by-turn-style
  /// spoken-prompt app: other audio keeps playing at a lower volume
  /// while the assistant is speaking, and is restored to full volume
  /// the moment [speak.onComplete] fires.
  ///
  /// Failures are logged and swallowed — falling back to default
  /// session behaviour (interrupt) is better than refusing to speak.
  Future<void> _configureAudioSessionForDucking() async {
    final tts = _tts;
    if (tts == null) return;
    if (!kIsWeb && Platform.isIOS) {
      try {
        await tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          <IosTextToSpeechAudioCategoryOptions>[
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.spokenAudio,
        );
        logger.info('[TTS] iOS audio session configured for ducking');
      } catch (e) {
        logger.warning('[TTS] iOS audio category set failed: $e');
      }
    }
  }

  /// Update the TTS language. Must be called after init().
  Future<void> setLanguage(String? language) async {
    if (kIsWeb || _tts == null) return;
    if (language != null && language.isNotEmpty) {
      await _tts!.setLanguage(language);
      logger.info('[TTS] Language updated to $language');
    }
  }

  /// Update the TTS engine. Must be called after init().
  Future<void> setEngine(String? engine) async {
    if (kIsWeb || _tts == null) return;
    if (engine != null && engine.isNotEmpty) {
      await _tts!.setEngine(engine);
      logger.info('[TTS] Engine updated to $engine');
    }
  }

  /// Get available TTS engines.
  Future<List<Map<String, String>>> getEngines() async {
    if (kIsWeb) return [];
    _tts ??= FlutterTts();
    try {
      final engines = await _tts!.getEngines;
      return _normalisePluginList(
        engines,
        stringKey: 'identifier',
        fallbackName: 'Engine',
      );
    } catch (error, stackTrace) {
      logger.error('[TTS] Failed to fetch engines', error, stackTrace);
      return [];
    }
  }

  /// Get available languages for the current engine.
  Future<List<Map<String, String>>> getLanguages() async {
    if (kIsWeb) return [];
    _tts ??= FlutterTts();
    try {
      final languages = await _tts!.getLanguages;
      return _normalisePluginList(
        languages,
        stringKey: 'code',
        fallbackName: 'Language',
      );
    } catch (error, stackTrace) {
      logger.error('[TTS] Failed to fetch languages', error, stackTrace);
      return [];
    }
  }

  /// Speak the given markdown text after stripping formatting.
  ///
  /// [token] is an opaque identifier (typically a message id) that
  /// listeners can use to map the currently-playing speech back to a
  /// source message — for example, to highlight it in the UI or to
  /// drive prev/next playback controls.
  ///
  /// When [useOffline] is true and the platform supports it, speech
  /// is generated by the local sherpa-onnx engine
  /// ([OfflineTtsService]); on any failure (model still
  /// downloading, generation error, no audio device) it transparently
  /// falls back to the system flutter_tts engine so the user always
  /// hears *something*.
  Future<void> speak(
    String markdown, {
    String? token,
    bool useOffline = false,
    String? offlineVoiceId,
  }) async {
    // User-initiated speech: clear any queued auto-speech so prev/next
    // and per-message taps respond immediately instead of being held
    // up behind queued auto-replies.
    _queue.clear();
    return _speakInternal(
      markdown,
      token: token,
      useOffline: useOffline,
      offlineVoiceId: offlineVoiceId,
    );
  }

  /// Queue [markdown] to be spoken after the current speech finishes.
  /// If nothing is currently playing, behaves like [speak].
  ///
  /// Used by the live chat gate so a new agent reply doesn't interrupt
  /// an earlier reply the user is still listening to.
  Future<void> enqueueSpeak(
    String markdown, {
    String? token,
    bool useOffline = false,
    String? offlineVoiceId,
  }) async {
    _attachSelfListenerIfNeeded();
    if (_currentToken.value == null && _queue.isEmpty) {
      return _speakInternal(
        markdown,
        token: token,
        useOffline: useOffline,
        offlineVoiceId: offlineVoiceId,
      );
    }
    _queue.add(
      _QueuedSpeech(
        markdown: markdown,
        token: token,
        useOffline: useOffline,
        offlineVoiceId: offlineVoiceId,
      ),
    );
    logger.info('[TTS] enqueued speech (queue size=${_queue.length})');
  }

  Future<void> _speakInternal(
    String markdown, {
    String? token,
    bool useOffline = false,
    String? offlineVoiceId,
  }) async {
    _attachSelfListenerIfNeeded();
    if (kIsWeb) {
      logger.warning('[TTS] speak skipped: kIsWeb');
      return;
    }
    final clean = _stripMarkdown(markdown);
    if (clean.isEmpty) {
      logger.warning(
        '[TTS] speak skipped: text empty '
        'after stripping markdown',
      );
      return;
    }
    logger.info(
      '[TTS] Speaking ${clean.length} chars: '
      '"${clean.substring(0, clean.length.clamp(0, 80))}..."',
    );

    if (useOffline && OfflineTtsService().isSupported) {
      // If sherpa-onnx's FFI binding probe failed during initialize,
      // the native library is unusable for this process; silently
      // fall back to the system engine without retrying so we don't
      // spawn doomed generate workers that raise "Please initialize
      // sherpa-onnx first" and forward to Sentry on every speak.
      final probeBroken =
          OfflineTtsService().isReady && OfflineTtsService().isProbeFailed;
      // If the offline engine's one-shot init hasn't completed yet
      // AND the requested voice isn't already extracted on disk,
      // skip offline this round and use the system engine so the
      // user-initiated tap responds immediately instead of blocking
      // on a sherpa probe (or, worse, racing past it). The next tap
      // — by which time `initialize()` has resolved — will use the
      // offline engine as configured.
      final initInFlight = !OfflineTtsService().isReady &&
          _offlineVoiceNotReady(offlineVoiceId);

      if (probeBroken) {
        _logFallbackOnce(
          '[TTS] offline engine unavailable on this device; '
          'using system TTS',
        );
        // fall through to flutter_tts
      } else if (initInFlight) {
        logger.info(
          '[TTS] offline engine not initialised yet; '
          'falling back to system TTS for this request',
        );
        // Fire-and-forget kick to make sure init keeps progressing
        // for subsequent calls.
        unawaited(OfflineTtsService().initialize());
        // fall through to flutter_tts
      } else {
        _attachOfflineListenerIfNeeded();
        // Cancel any system-engine speech before switching backends so
        // the two engines don't speak over each other.
        if (_initialized && _tts != null) {
          try {
            await _tts!.stop();
          } catch (_) {/* ignore */}
        }
        _activeBackend = _Backend.offline;
        _setCurrentToken(token);
        _currentText.value = clean;
        try {
          await OfflineTtsService().speak(
            clean,
            token: token,
            voiceId: offlineVoiceId,
          );
          return;
        } catch (e, st) {
          // Distinguish "engine genuinely unavailable" (sherpa-onnx
          // bindings missing — common on devices without the native
          // .so) from real generation/playback failures. The former
          // is expected on those devices and the user still gets
          // speech via the system engine, so we log at info level
          // (one-shot per session) to keep Sentry quiet. Anything
          // else is a real bug worth capturing.
          if (e is OfflineTtsException) {
            _logFallbackOnce(
              '[TTS] offline engine unavailable, '
              'using system TTS: $e',
            );
          } else {
            logger.warning(
              '[TTS] offline speak failed, '
              'falling back to system engine: $e',
              e,
              st,
            );
          }
          _activeBackend = _Backend.system;
          // fall through to flutter_tts
        }
      }
    }

    if (_tts == null) {
      logger.warning(
        '[TTS] speak skipped: _tts is null '
        '(call init() first)',
      );
      _setCurrentToken(null);
      _currentText.value = null;
      return;
    }
    _activeBackend = _Backend.system;
    try {
      await _tts!.stop();
    } catch (e) {
      _tts = null;
      _initialized = false;
      _setCurrentToken(null);
      _currentText.value = null;
      logger.warning('[TTS] speak skipped: $e');
      return;
    }
    _setCurrentToken(token);
    _currentText.value = clean;
    // `focus: true` asks the plugin to request
    // `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` on Android — the system
    // lowers the volume of any currently-playing music/podcast while
    // we speak, and restores it to its original volume the moment the
    // utterance completes. On non-Android platforms the parameter is
    // ignored; iOS ducking is handled by the audio-session category
    // configured in [_configureAudioSessionForDucking].
    final focus = !kIsWeb && Platform.isAndroid;
    final result = await _tts!.speak(clean, focus: focus);
    logger.info('[TTS] speak() returned: $result');
  }

  /// Stop any in-progress speech (across both backends).
  Future<void> stop() async {
    _queue.clear();
    _setCurrentToken(null);
    _currentText.value = null;
    // Stop the offline backend best-effort even if it's not the
    // currently active one — better to over-stop than to leave
    // audio playing after a session change.
    try {
      await OfflineTtsService().stop();
    } catch (_) {/* ignore */}
    if (kIsWeb || _tts == null) return;
    try {
      await _tts!.stop();
    } catch (_) {
      _tts = null;
      _initialized = false;
    }
  }

  /// Release engine resources.
  Future<void> dispose() async {
    _queue.clear();
    _setCurrentToken(null);
    _currentText.value = null;
    try {
      await OfflineTtsService().dispose();
    } catch (_) {/* ignore */}
    if (_tts != null) {
      try {
        await _tts!.stop();
      } catch (_) {
        // TTS not supported on this platform; nothing to stop.
      }
      _tts = null;
      _initialized = false;
    }
  }

  /// Remove common markdown syntax so TTS reads clean prose.
  static String _stripMarkdown(String md) {
    var text = md;
    // Remove fenced code blocks (``` ... ```)
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    // Remove inline code
    text = text.replaceAll(RegExp(r'`[^`]+`'), '');
    // Remove images ![alt](url)
    text = text.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '');
    // Convert links [text](url) → text
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (m) => m.group(1) ?? '',
    );
    // Remove bold/italic markers
    text = text.replaceAll(RegExp(r'\*{1,3}'), '');
    text = text.replaceAll(RegExp(r'_{1,3}'), '');
    // Remove headings markers
    text = text.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // Remove blockquote markers
    text = text.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
    // Remove horizontal rules
    text = text.replaceAll(RegExp(r'^[-*_]{3,}\s*$', multiLine: true), '');
    // Remove list markers
    text = text.replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
    // Collapse whitespace
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  static List<Map<String, String>> _normalisePluginList(
    dynamic rawList, {
    required String stringKey,
    required String fallbackName,
  }) {
    if (rawList is! List) return const [];
    return rawList
        .map(
          (entry) => _normalisePluginEntry(
            entry,
            stringKey: stringKey,
            fallbackName: fallbackName,
          ),
        )
        .whereType<Map<String, String>>()
        .toList();
  }

  /// Trigger a download of the offline TTS model (no-op if already
  /// present). Surfaces the error if the download fails.
  Future<void> ensureOfflineReady() => OfflineTtsService().ensureReady();

  /// Trigger a download of a specific offline voice.
  Future<void> ensureOfflineVoice(String voiceId) =>
      OfflineTtsService().ensureVoice(voiceId);

  /// Remove an offline voice from disk.
  Future<void> deleteOfflineVoice(String voiceId) =>
      OfflineTtsService().deleteVoice(voiceId);

  /// Select which offline voice [speak] uses when `useOffline: true`.
  void selectOfflineVoice(String voiceId) =>
      OfflineTtsService().selectVoice(voiceId);

  /// Walk the cache directory and refresh per-voice statuses.
  Future<void> refreshOfflineVoiceStatuses() =>
      OfflineTtsService().refreshStatuses();

  /// All offline voices the user can choose from.
  List<OfflineTtsModel> get offlineVoices => OfflineTtsService().voices;

  /// Per-voice download status snapshot.
  ValueListenable<Map<String, OfflineTtsStatus>> get offlineVoiceStatuses =>
      OfflineTtsService().statuses;

  /// Last error for a given voice (or `null`).
  Object? offlineVoiceError(String voiceId) =>
      OfflineTtsService().errorFor(voiceId);

  /// Listenable for the offline model availability status. Used by
  /// the voice settings screen to drive a "Download offline voice"
  /// button.
  ValueListenable<OfflineTtsStatus> get offlineStatus =>
      OfflineTtsService().status;

  /// Last error from the offline model download/extract pipeline,
  /// or `null` if the pipeline never failed in this process.
  Object? get offlineLastError => OfflineTtsService().lastError;

  /// Whether the offline backend is supported on this platform
  /// (false on web).
  bool get isOfflineSupported => OfflineTtsService().isSupported;

  static Map<String, String>? _normalisePluginEntry(
    dynamic entry, {
    required String stringKey,
    required String fallbackName,
  }) {
    if (entry is Map) {
      final mapped = <String, String>{};
      for (final pair in entry.entries) {
        mapped[pair.key.toString()] = pair.value.toString();
      }
      return mapped;
    }
    if (entry is String) {
      return <String, String>{'name': entry, stringKey: entry};
    }
    if (entry == null) return null;
    final value = entry.toString();
    return <String, String>{'name': '$fallbackName $value', stringKey: value};
  }
}

class _QueuedSpeech {
  const _QueuedSpeech({
    required this.markdown,
    required this.token,
    required this.useOffline,
    required this.offlineVoiceId,
  });

  final String markdown;
  final String? token;
  final bool useOffline;
  final String? offlineVoiceId;
}
