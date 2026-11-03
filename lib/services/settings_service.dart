import 'package:shared_preferences/shared_preferences.dart';

class AmiSettings {
  const AmiSettings({
    this.apiKey = '',
    this.model = 'gemini-3.6-flash',
    this.voiceLocale = 'auto',
    this.autoSpeak = true,
    this.autoScreen = true,
  });

  final String apiKey;
  final String model;
  final String voiceLocale;
  final bool autoSpeak;
  final bool autoScreen;

  bool get hasApiKey => apiKey.trim().isNotEmpty;

  AmiSettings copyWith({
    String? apiKey,
    String? model,
    String? voiceLocale,
    bool? autoSpeak,
    bool? autoScreen,
  }) =>
      AmiSettings(
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
        voiceLocale: voiceLocale ?? this.voiceLocale,
        autoSpeak: autoSpeak ?? this.autoSpeak,
        autoScreen: autoScreen ?? this.autoScreen,
      );
}

class SettingsService {
  static const _kApiKey = 'ami_api_key';
  static const _kModel = 'ami_model';
  static const _kVoiceLocale = 'ami_voice_locale';
  static const _kAutoSpeak = 'ami_auto_speak';
  static const _kAutoScreen = 'ami_auto_screen';

  Future<AmiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AmiSettings(
      apiKey: prefs.getString(_kApiKey) ?? '',
      model: prefs.getString(_kModel) ?? 'gemini-3.6-flash',
      voiceLocale: prefs.getString(_kVoiceLocale) ?? 'auto',
      autoSpeak: prefs.getBool(_kAutoSpeak) ?? true,
      autoScreen: prefs.getBool(_kAutoScreen) ?? true,
    );
  }

  Future<void> save(AmiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKey, settings.apiKey.trim());
    await prefs.setString(_kModel, settings.model.trim());
    await prefs.setString(_kVoiceLocale, settings.voiceLocale);
    await prefs.setBool(_kAutoSpeak, settings.autoSpeak);
    await prefs.setBool(_kAutoScreen, settings.autoScreen);
  }
}
