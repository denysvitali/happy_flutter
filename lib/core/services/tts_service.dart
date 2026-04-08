import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'logger_service.dart' show logger;

/// Text-to-speech service using the device's built-in TTS engine.
///
/// Strips markdown formatting before speaking so the user hears
/// clean, natural text.
class TtsService {
  factory TtsService() => _instance;
  TtsService._();
  static final TtsService _instance = TtsService._();

  FlutterTts? _tts;
  bool _initialized = false;

  /// Initialise the TTS engine. Safe to call multiple times.
  Future<void> init({String? language, String? engine}) async {
    if (kIsWeb) return; // TTS not supported on web
    logger.info('[TTS] init called (initialized=$_initialized)');
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
      _tts!.setStartHandler(() {
        logger.info('[TTS] Speech started');
      });
      _tts!.setCompletionHandler(() {
        logger.info('[TTS] Speech completed');
      });
      _tts!.setErrorHandler((msg) {
        logger.error('[TTS] Error: $msg');
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
  Future<void> speak(String markdown) async {
    if (kIsWeb) {
      logger.warning('[TTS] speak skipped: kIsWeb');
      return;
    }
    if (_tts == null) {
      logger.warning('[TTS] speak skipped: _tts is null '
          '(call init() first)');
      return;
    }
    final clean = _stripMarkdown(markdown);
    if (clean.isEmpty) {
      logger.warning('[TTS] speak skipped: text empty '
          'after stripping markdown');
      return;
    }
    logger.info('[TTS] Speaking ${clean.length} chars: '
        '"${clean.substring(0, clean.length.clamp(0, 80))}..."');
    try {
      await _tts!.stop();
    } catch (e) {
      _tts = null;
      _initialized = false;
      logger.warning('[TTS] speak skipped: $e');
      return;
    }
    final result = await _tts!.speak(clean);
    logger.info('[TTS] speak() returned: $result');
  }

  /// Stop any in-progress speech.
  Future<void> stop() async {
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
    text = text.replaceAll(
      RegExp(r'```[\s\S]*?```'),
      '',
    );
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
    text = text.replaceAll(
      RegExp(r'^\s*[-*+]\s+', multiLine: true),
      '',
    );
    text = text.replaceAll(
      RegExp(r'^\s*\d+\.\s+', multiLine: true),
      '',
    );
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
      return <String, String>{
        'name': entry,
        stringKey: entry,
      };
    }
    if (entry == null) return null;
    final value = entry.toString();
    return <String, String>{
      'name': '$fallbackName $value',
      stringKey: value,
    };
  }
}
