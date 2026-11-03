import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceListenEnd { finished, cancelled, error }

class VoiceService {
  VoiceService() {
    _tts.setStartHandler(() => _setSpeaking(true));
    _tts.setCompletionHandler(() => _setSpeaking(false));
    _tts.setCancelHandler(() => _setSpeaking(false));
    _tts.setErrorHandler((_) => _setSpeaking(false));
  }

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  void Function(bool speaking)? onSpeakingChanged;
  void Function(bool listening)? onListeningChanged;

  final Map<String, Map<String, String>> _voiceCache = {};

  bool _ttsReady = false;
  bool _sttReady = false;
  bool _listening = false;
  bool _speaking = false;
  bool _disposed = false;

  bool get isListening => _listening;
  bool get isSpeaking => _speaking;

  void _setListening(bool value) {
    if (_listening == value) return;
    _listening = value;
    onListeningChanged?.call(value);
  }

  void _setSpeaking(bool value) {
    if (_speaking == value) return;
    _speaking = value;
    onSpeakingChanged?.call(value);
  }

  Future<bool> initializeSpeech() async {
    if (_sttReady) return true;
    try {
      _sttReady = await _speech.initialize(
        onError: (_) {},
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _setListening(false);
          }
        },
      );
    } catch (_) {
      _sttReady = false;
    }
    return _sttReady;
  }

  Future<bool> initializeTts() async {
    if (_ttsReady) return true;
    try {
      if (Platform.isAndroid) {
        try {
          await _tts.setEngine('com.google.android.tts');
        } catch (_) {}
      }
      await _tts.awaitSpeakCompletion(true);
      await _tts.setSpeechRate(0.47);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      if (Platform.isIOS) {
        await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        ]);
      }
      _ttsReady = true;
    } catch (_) {
      _ttsReady = false;
    }
    return _ttsReady;
  }

  Future<void> listen({
    required void Function(String words, bool isFinal) onResult,
    required void Function(double level) onLevel,
    required void Function(VoiceListenEnd end) onEnd,
    String localeId = 'auto',
    Duration maxDuration = const Duration(seconds: 45),
  }) async {
    if (_disposed) return;
    final ready = await initializeSpeech();
    if (!ready) {
      onEnd(VoiceListenEnd.error);
      return;
    }
    await _tts.stop();
    _setListening(true);

    final options = SpeechListenOptions(
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.dictation,
      localeId: localeId == 'auto' ? null : localeId,
      pauseFor: const Duration(seconds: 3),
      listenFor: maxDuration,
    );

    try {
      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          onResult(words, result.finalResult);
          if (result.finalResult) {
            _setListening(false);
          }
        },
        onSoundLevelChange: (level) {
          final normalized = level.clamp(-2.0, 10.0);
          onLevel(((normalized + 2) / 12).clamp(0.0, 1.0));
        },
        listenOptions: options,
      );
    } catch (_) {
      _setListening(false);
      onEnd(VoiceListenEnd.error);
    }
  }

  Future<void> stopListening() async {
    if (!_listening) return;
    try {
      await _speech.stop();
    } catch (_) {}
    _setListening(false);
  }

  Future<void> speak(String text, {String localeId = 'auto'}) async {
    if (_disposed || text.trim().isEmpty) return;
    if (!await initializeTts()) return;
    await stopListening();
    try {
      await _tts.stop();
      final language = await _resolveLanguage(text, localeId);
      await _tts.setLanguage(language);
      await _applyBestVoice(language);
      await _tts.speak(_prepareTextForSpeech(text));
    } catch (_) {
      _setSpeaking(false);
    }
  }

  String _prepareTextForSpeech(String text) => text
      .replaceAll(RegExp(r'[\r\n]+'), ' ')
      .replaceAll(RegExp(r'[-–—]+'), ' ')
      .replaceAll('।', '। ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<void> _applyBestVoice(String language) async {
    final cached = _voiceCache[language];
    if (cached != null) {
      try {
        await _tts.setVoice(cached);
      } catch (_) {}
      return;
    }
    try {
      final rawVoices = await _tts.getVoices;
      if (rawVoices is! List) return;
      final target = language.toLowerCase();
      final base = target.split('-').first;
      Map<String, String>? best;
      var bestScore = -1;
      for (final raw in rawVoices) {
        if (raw is! Map) continue;
        final voice = <String, String>{};
        raw.forEach((key, value) {
          if (key != null && value != null) voice['$key'] = '$value';
        });
        final locale = (voice['locale'] ?? '').toLowerCase().replaceAll(
          '_',
          '-',
        );
        if (locale != target &&
            locale != base &&
            !locale.startsWith('$base-')) {
          continue;
        }
        final quality = voice['quality'] ?? '';
        final features = (voice['features'] ?? '').toLowerCase();
        final name = (voice['name'] ?? '').toLowerCase();
        var score = switch (quality) {
          'very high' => 60,
          'high' => 45,
          'normal' => 25,
          'low' => 5,
          'very low' => 0,
          _ => 10,
        };
        if (voice['network_required'] == '1') score += 30;
        if (name.contains('neural') || features.contains('neural')) {
          score += 45;
        }
        if (name.contains('wavenet') || features.contains('wavenet')) {
          score += 45;
        }
        if (name.contains('studio') || features.contains('studio')) {
          score += 35;
        }
        if (features.contains('enhanced')) score += 20;
        if (name.contains('network')) score += 15;
        if (locale == target) score += 10;
        if (score > bestScore) {
          bestScore = score;
          best = voice;
        }
      }
      final name = best?['name'];
      if (name != null && name.isNotEmpty) {
        final selection = {'name': name, 'locale': best?['locale'] ?? language};
        await _tts.setVoice(selection);
        _voiceCache[language] = selection;
      }
    } catch (_) {}
  }

  Future<String> _resolveLanguage(String text, String requested) async {
    if (requested != 'auto') return requested;
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(text)) {
      if (await _isLanguageAvailable('bn-IN')) return 'bn-IN';
    }
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      if (await _isLanguageAvailable('hi-IN')) return 'hi-IN';
    }
    final deviceLocale = await _tts.getDefaultVoice;
    final locale = deviceLocale is Map ? deviceLocale['locale'] : null;
    return locale is String && locale.isNotEmpty ? locale : 'en-US';
  }

  Future<bool> _isLanguageAvailable(String language) async {
    try {
      return await _tts.isLanguageAvailable(language) == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _setSpeaking(false);
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _speech.cancel();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
