import 'package:flutter/foundation.dart';
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
      await _tts!.setSpeechRate(0.5);
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.0);
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
    if (kIsWeb || _tts == null) return [];
    final engines = await _tts!.getEngines;
    if (engines == null) return [];
    return (engines as List).map((e) {
      final map = e as Map<Object?, Object?>;
      return map.map((k, v) => MapEntry(k.toString(), v.toString()));
    }).toList();
  }

  /// Get available languages for the current engine.
  Future<List<Map<String, String>>> getLanguages() async {
    if (kIsWeb || _tts == null) return [];
    final languages = await _tts!.getLanguages;
    if (languages == null) return [];
    return (languages as List).map((e) {
      final map = e as Map<Object?, Object?>;
      return map.map((k, v) => MapEntry(k.toString(), v.toString()));
    }).toList();
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
    await _tts!.stop();
    final result = await _tts!.speak(clean);
    logger.info('[TTS] speak() returned: $result');
  }

  /// Stop any in-progress speech.
  Future<void> stop() async {
    if (kIsWeb || _tts == null) return;
    await _tts!.stop();
  }

  /// Release engine resources.
  Future<void> dispose() async {
    if (_tts != null) {
      await _tts!.stop();
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
}
