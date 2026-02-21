import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  Future<void> init({String? language}) async {
    if (kIsWeb) return; // TTS not supported on web
    _tts ??= FlutterTts();
    if (!_initialized) {
      await _tts!.setSpeechRate(0.5);
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(1.0);
      _initialized = true;
    }
    if (language != null && language.isNotEmpty) {
      await _tts!.setLanguage(language);
    }
  }

  /// Speak the given markdown text after stripping formatting.
  Future<void> speak(String markdown) async {
    if (kIsWeb || _tts == null) return;
    final clean = _stripMarkdown(markdown);
    if (clean.isEmpty) return;
    await _tts!.stop();
    await _tts!.speak(clean);
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
