import 'dart:async';
import 'package:flutter/foundation.dart';

import 'models/chat_message.dart';
import 'services/accessibility_bridge.dart';
import 'services/gemini_service.dart';
import 'services/overlay_service.dart';
import 'services/screen_capture_service.dart';
import 'services/settings_service.dart';
import 'services/voice_service.dart';

enum AmiActivity { idle, listening, thinking, speaking }

class AmiController extends ChangeNotifier {
  AmiController({
    SettingsService? settingsService,
    GeminiService? gemini,
    ScreenCaptureService? screen,
    VoiceService? voice,
    OverlayService? overlay,
    AccessibilityBridge? accessibility,
  })  : _settingsService = settingsService ?? SettingsService(),
        _gemini = gemini ?? GeminiService(),
        _screen = screen ?? ScreenCaptureService(),
        _voice = voice ?? VoiceService(),
        _overlay = overlay ?? OverlayService(),
        _accessibility = accessibility ?? AccessibilityBridge() {
    _screen.isSharing.addListener(_onScreenChanged);
    _screen.onDelayedCaptureReady = _handleDelayedCapture;
    _overlay.onOrbTap = _handleOrbTap;
    _voice.onSpeakingChanged = (speaking) {
      _isSpeaking = speaking;
      notifyListeners();
    };
    _voice.onListeningChanged = _handleVoiceListening;
  }

  final SettingsService _settingsService;
  final GeminiService _gemini;
  final ScreenCaptureService _screen;
  final VoiceService _voice;
  final OverlayService _overlay;
  final AccessibilityBridge _accessibility;

  AmiSettings settings = const AmiSettings();
  final List<ChatMessage> messages = [];

  bool booting = true;
  bool _isListening = false;
  bool _isThinking = false;
  bool _isSpeaking = false;
  bool screenBusy = false;
  bool accessibilityEnabled = false;
  bool accessibilityConnected = false;
  double soundLevel = 0;
  String transcript = '';
  String? notice;
  int captureCountdown = 0;
  Uint8List? lastFrame;

  Timer? _countdownTimer;
  bool _voiceHandled = false;
  bool _pendingOrbRead = false;

  bool get screenActive => _screen.isSharing.value;
  bool get hasApiKey => settings.hasApiKey;
  bool get isListening => _isListening;
  bool get isThinking => _isThinking;
  bool get isSpeaking => _isSpeaking;

  AmiActivity get activity {
    if (_isThinking) return AmiActivity.thinking;
    if (_isListening) return AmiActivity.listening;
    if (_isSpeaking) return AmiActivity.speaking;
    return AmiActivity.idle;
  }

  Future<void> init() async {
    try {
      settings = await _settingsService.load();
    } catch (_) {
      settings = const AmiSettings();
    }
    await refreshAccessibilityState();
    if (messages.isEmpty) {
      messages.add(_welcomeMessage());
    }
    final pendingAction = await _overlay.takePendingAction();
    if (pendingAction == 'read_screen') _pendingOrbRead = true;
    booting = false;
    notifyListeners();
    unawaited(_voice.initializeTts());
    if (settings.floatingRobot) {
      unawaited(_overlay.start());
    }
    if (_pendingOrbRead) {
      _pendingOrbRead = false;
      unawaited(analyzeScreenNow());
    }
  }

  void _handleOrbTap() {
    if (booting) {
      _pendingOrbRead = true;
      return;
    }
    unawaited(analyzeScreenNow());
  }

  Future<bool> setFloatingRobot(bool enabled) async {
    if (!enabled) {
      await _overlay.stop();
      settings = settings.copyWith(floatingRobot: false);
      await _settingsService.save(settings);
      notifyListeners();
      return true;
    }
    final granted = await _overlay.isPermissionGranted();
    if (!granted) {
      await _overlay.requestPermission();
      notice = 'Allow "Display over other apps" for AMI, then turn the '
          'floating robot on again.';
      notifyListeners();
      return false;
    }
    final started = await _overlay.start();
    if (!started) {
      notice = 'The floating robot could not start. Check overlay permission.';
      notifyListeners();
      return false;
    }
    settings = settings.copyWith(floatingRobot: true);
    await _settingsService.save(settings);
    notice = null;
    notifyListeners();
    return true;
  }

  ChatMessage _welcomeMessage() => ChatMessage(
        role: MessageRole.assistant,
        text:
            "Hey, I'm AMI — your screen-aware voice companion. Tap the orb and talk to me, or turn on screen context and I'll look at what you're seeing.",
      );

  void _onScreenChanged() {
    if (!screenActive) {
      lastFrame = null;
    }
    notifyListeners();
  }

  Future<void> toggleScreenShare() async {
    if (screenBusy) return;
    if (screenActive) {
      await _screen.stop();
      lastFrame = null;
      notice = 'Screen context is off.';
      notifyListeners();
      return;
    }
    screenBusy = true;
    notice = null;
    notifyListeners();
    try {
      final started = await _screen.start();
      notice = started
          ? 'Screen context is on. I can see what you see.'
          : 'Screen sharing was cancelled.';
    } catch (error) {
      notice = error is ScreenCaptureException
          ? error.message
          : 'Screen sharing could not be started.';
    }
    screenBusy = false;
    notifyListeners();
  }

  Future<void> lookAtScreenIn({int seconds = 5}) async {
    if (!screenActive) {
      await toggleScreenShare();
      if (!screenActive) return;
    }
    final started = await _screen.captureAfter(Duration(seconds: seconds));
    if (!started) {
      notice = 'I could not schedule that screen look. Try again.';
      notifyListeners();
      return;
    }
    notice =
        'Switch to the app you want me to see. I will look in $seconds seconds.';
    _startCountdown(seconds);
    notifyListeners();
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    captureCountdown = seconds;
    notifyListeners();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      captureCountdown = captureCountdown - 1;
      if (captureCountdown <= 0) {
        captureCountdown = 0;
        timer.cancel();
      }
      notifyListeners();
    });
  }

  Future<void> _handleDelayedCapture() async {
    final bytes = await _screen.takePendingCapture();
    if (bytes == null) {
      _countdownTimer?.cancel();
      captureCountdown = 0;
      notice = 'I could not read the screen. Is screen context still on?';
      notifyListeners();
      return;
    }
    await _consumePending(bytes);
  }

  Future<void> _consumePending(Uint8List bytes) async {
    _countdownTimer?.cancel();
    captureCountdown = 0;
    lastFrame = bytes;
    notifyListeners();
    await sendMessage(
      "What's on my screen right now? Tell me what you see and help me with it.",
      providedFrame: bytes,
    );
  }

  void _handleVoiceListening(bool listening) {
    if (listening) {
      if (!_isListening) {
        _isListening = true;
        notifyListeners();
      }
      return;
    }
    if (!_isListening || _voiceHandled) return;
    _isListening = false;
    soundLevel = 0;
    final text = transcript.trim();
    if (text.isEmpty) {
      notice = "I didn't catch that. Tap the orb and try again.";
    } else {
      _voiceHandled = true;
      unawaited(sendMessage(text));
    }
    notifyListeners();
  }

  Future<void> analyzeScreenNow() async {
    if (!screenActive) {
      await toggleScreenShare();
      if (!screenActive) return;
    }
    final bytes = await _grabScreen();
    if (bytes != null) lastFrame = bytes;
    await sendMessage(
      "What's on my screen right now? Tell me what you see and help me with it.",
      providedFrame: bytes,
    );
  }

  Future<void> toggleVoice() async {
    if (_isThinking) return;
    if (_isSpeaking) {
      await _voice.stopSpeaking();
      return;
    }
    if (_isListening) {
      await _finishListening();
      return;
    }

    notice = null;
    final ready = await _voice.initializeSpeech();
    if (!ready) {
      notice =
          'Microphone permission is needed. Allow it in Android settings and try again.';
      notifyListeners();
      return;
    }

    _voiceHandled = false;
    transcript = '';
    soundLevel = 0;
    _isListening = true;
    notifyListeners();

    await _voice.listen(
      localeId: settings.voiceLocale,
      onResult: (words, isFinal) {
        if (words.isNotEmpty) {
          transcript = words;
          notifyListeners();
        }
        if (isFinal && !_voiceHandled) {
          _voiceHandled = true;
          _isListening = false;
          soundLevel = 0;
          notifyListeners();
          final text = words.trim();
          if (text.isEmpty) {
            notice = "I didn't catch that. Tap the orb and try again.";
            notifyListeners();
          } else {
            unawaited(sendMessage(text));
          }
        }
      },
      onLevel: (level) {
        soundLevel = level;
        if (_isListening) notifyListeners();
      },
      onEnd: (end) {
        if (end == VoiceListenEnd.error) {
          _isListening = false;
          soundLevel = 0;
          notice = 'Voice input stopped. Check the microphone permission.';
          notifyListeners();
        }
      },
    );
  }

  Future<void> _finishListening() async {
    await _voice.stopListening();
    _isListening = false;
    soundLevel = 0;
    final text = transcript.trim();
    _voiceHandled = true;
    if (text.isEmpty) {
      notice = 'I stopped listening. Tap the orb when you are ready.';
    } else {
      unawaited(sendMessage(text));
    }
    notifyListeners();
  }

  Future<void> sendMessage(
    String text, {
    Uint8List? providedFrame,
    bool? includeScreen,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isThinking) return;

    if (!hasApiKey) {
      notice = 'Add your Gemini API key in Settings to chat with AMI.';
      messages.add(ChatMessage(
        role: MessageRole.assistant,
        text: notice!,
        isError: true,
      ));
      notifyListeners();
      return;
    }

    await _voice.stopSpeaking();

    Uint8List? frame = providedFrame;
    final wantsScreen =
        includeScreen ?? (settings.autoScreen && screenActive);
    if (frame == null && wantsScreen && screenActive) {
      frame = await _grabScreen();
    }
    if (frame != null) lastFrame = frame;

    messages.add(ChatMessage(
      role: MessageRole.user,
      text: trimmed,
      image: frame,
    ));
    _isThinking = true;
    transcript = '';
    notice = null;
    notifyListeners();

    try {
      final reply = await _gemini.generate(
        apiKey: settings.apiKey,
        model: settings.model,
        history: messages,
        screenshot: frame,
        localeHint: settings.voiceLocale,
      );
      messages.add(ChatMessage(role: MessageRole.assistant, text: reply));
      _isThinking = false;
      notifyListeners();
      if (settings.autoSpeak) {
        unawaited(_voice.speak(reply, localeId: settings.voiceLocale));
      }
    } catch (error) {
      _isThinking = false;
      final message = error is GeminiException
          ? error.message
          : 'Something went wrong while talking to Gemini. Please try again.';
      messages.add(ChatMessage(
        role: MessageRole.assistant,
        text: message,
        isError: true,
      ));
      notice = message;
      notifyListeners();
    }
  }

  Future<Uint8List?> _grabScreen({int attempts = 6}) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      final bytes = await _screen.capture();
      if (bytes != null) return bytes;
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
    return null;
  }

  Future<void> speakMessage(String text) async {
    if (_isSpeaking) {
      await _voice.stopSpeaking();
    } else {
      await _voice.speak(text, localeId: settings.voiceLocale);
    }
  }

  Future<void> saveSettings(AmiSettings next) async {
    settings = next;
    if (!next.autoSpeak) {
      await _voice.stopSpeaking();
    }
    await _settingsService.save(next);
    notifyListeners();
  }

  void clearChat() {
    messages
      ..clear()
      ..add(_welcomeMessage());
    lastFrame = null;
    notice = null;
    notifyListeners();
  }

  void clearNotice() {
    notice = null;
    notifyListeners();
  }

  Future<void> refreshScreenState() async {
    await _screen.refresh();
    await refreshAccessibilityState();
    if (settings.floatingRobot) {
      unawaited(_overlay.start());
    }
    final action = await _overlay.takePendingAction();
    if (action == 'read_screen') {
      unawaited(analyzeScreenNow());
      return;
    }
    final pending = await _screen.takePendingCapture();
    if (pending != null) {
      unawaited(_consumePending(pending));
    } else {
      notifyListeners();
    }
  }

  Future<void> refreshAccessibilityState() async {
    accessibilityEnabled = await _accessibility.isEnabled();
    accessibilityConnected = await _accessibility.isConnected();
    notifyListeners();
  }

  Future<bool> openAccessibilitySettings() => _accessibility.openSettings();

  Future<List<Map<String, dynamic>>> readScreenNodes() async {
    if (!settings.accessibilityConsent || !accessibilityConnected) return [];
    return _accessibility.getScreenNodes();
  }

  Future<bool> tapAt(double x, double y) async {
    if (!settings.accessibilityConsent || !accessibilityConnected) return false;
    return _accessibility.tapAt(x, y);
  }

  Future<bool> typeText(String text) async {
    if (!settings.accessibilityConsent || !accessibilityConnected) return false;
    return _accessibility.typeText(text);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _screen.isSharing.removeListener(_onScreenChanged);
    _screen.onDelayedCaptureReady = null;
    _overlay.onOrbTap = null;
    _screen.dispose();
    _voice.dispose();
    super.dispose();
  }
}
