import 'package:shared_preferences/shared_preferences.dart';

class AmiSettings {
  const AmiSettings({
    this.apiKey = '',
    this.model = 'gemini-3.6-flash',
    this.provider = 'gemini',
    this.groqApiKey = '',
    this.groqModel = 'qwen/qwen3.8-27b',
    this.cloudflareAccountId = '',
    this.cloudflareApiToken = '',
    this.cloudflareModel = '@cf/google/gemma-4-26b-a4b-it',
    this.voiceLocale = 'auto',
    this.autoSpeak = true,
    this.autoScreen = true,
    this.floatingRobot = false,
    this.accessibilityConsent = false,
    this.screenActionConsent = false,
  });

  final String apiKey;
  final String model;
  final String provider;
  final String groqApiKey;
  final String groqModel;
  final String cloudflareAccountId;
  final String cloudflareApiToken;
  final String cloudflareModel;
  final String voiceLocale;
  final bool autoSpeak;
  final bool autoScreen;
  final bool floatingRobot;
  final bool accessibilityConsent;
  final bool screenActionConsent;

  bool get hasApiKey => switch (provider) {
    'groq' => groqApiKey.trim().isNotEmpty,
    'cloudflare' =>
      cloudflareAccountId.trim().isNotEmpty &&
          cloudflareApiToken.trim().isNotEmpty,
    _ => apiKey.trim().isNotEmpty,
  };

  AmiSettings copyWith({
    String? apiKey,
    String? model,
    String? provider,
    String? groqApiKey,
    String? groqModel,
    String? cloudflareAccountId,
    String? cloudflareApiToken,
    String? cloudflareModel,
    String? voiceLocale,
    bool? autoSpeak,
    bool? autoScreen,
    bool? floatingRobot,
    bool? accessibilityConsent,
    bool? screenActionConsent,
  }) => AmiSettings(
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    provider: provider ?? this.provider,
    groqApiKey: groqApiKey ?? this.groqApiKey,
    groqModel: groqModel ?? this.groqModel,
    cloudflareAccountId: cloudflareAccountId ?? this.cloudflareAccountId,
    cloudflareApiToken: cloudflareApiToken ?? this.cloudflareApiToken,
    cloudflareModel: cloudflareModel ?? this.cloudflareModel,
    voiceLocale: voiceLocale ?? this.voiceLocale,
    autoSpeak: autoSpeak ?? this.autoSpeak,
    autoScreen: autoScreen ?? this.autoScreen,
    floatingRobot: floatingRobot ?? this.floatingRobot,
    accessibilityConsent: accessibilityConsent ?? this.accessibilityConsent,
    screenActionConsent: screenActionConsent ?? this.screenActionConsent,
  );
}

class SettingsService {
  static const _kApiKey = 'ami_api_key';
  static const _kModel = 'ami_model';
  static const _kProvider = 'ami_provider';
  static const _kGroqApiKey = 'ami_groq_api_key';
  static const _kGroqModel = 'ami_groq_model';
  static const _kCloudflareAccountId = 'ami_cloudflare_account_id';
  static const _kCloudflareApiToken = 'ami_cloudflare_api_token';
  static const _kCloudflareModel = 'ami_cloudflare_model';
  static const _kVoiceLocale = 'ami_voice_locale';
  static const _kAutoSpeak = 'ami_auto_speak';
  static const _kAutoScreen = 'ami_auto_screen';
  static const _kFloatingRobot = 'ami_floating_robot';
  static const _kAccessibilityConsent = 'ami_accessibility_consent';
  static const _kScreenActionConsent = 'ami_screen_action_consent';

  Future<AmiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AmiSettings(
      apiKey: prefs.getString(_kApiKey) ?? '',
      model: prefs.getString(_kModel) ?? 'gemini-3.6-flash',
      provider: prefs.getString(_kProvider) ?? 'gemini',
      groqApiKey: prefs.getString(_kGroqApiKey) ?? '',
      groqModel: prefs.getString(_kGroqModel) ?? 'qwen/qwen3.8-27b',
      cloudflareAccountId: prefs.getString(_kCloudflareAccountId) ?? '',
      cloudflareApiToken: prefs.getString(_kCloudflareApiToken) ?? '',
      cloudflareModel:
          prefs.getString(_kCloudflareModel) ?? '@cf/google/gemma-4-26b-a4b-it',
      voiceLocale: prefs.getString(_kVoiceLocale) ?? 'auto',
      autoSpeak: prefs.getBool(_kAutoSpeak) ?? true,
      autoScreen: prefs.getBool(_kAutoScreen) ?? true,
      floatingRobot: prefs.getBool(_kFloatingRobot) ?? false,
      accessibilityConsent: prefs.getBool(_kAccessibilityConsent) ?? false,
      screenActionConsent: prefs.getBool(_kScreenActionConsent) ?? false,
    );
  }

  Future<void> save(AmiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kApiKey, settings.apiKey.trim());
    await prefs.setString(_kModel, settings.model.trim());
    await prefs.setString(_kProvider, settings.provider);
    await prefs.setString(_kGroqApiKey, settings.groqApiKey.trim());
    await prefs.setString(_kGroqModel, settings.groqModel.trim());
    await prefs.setString(
      _kCloudflareAccountId,
      settings.cloudflareAccountId.trim(),
    );
    await prefs.setString(
      _kCloudflareApiToken,
      settings.cloudflareApiToken.trim(),
    );
    await prefs.setString(_kCloudflareModel, settings.cloudflareModel.trim());
    await prefs.setString(_kVoiceLocale, settings.voiceLocale);
    await prefs.setBool(_kAutoSpeak, settings.autoSpeak);
    await prefs.setBool(_kAutoScreen, settings.autoScreen);
    await prefs.setBool(_kFloatingRobot, settings.floatingRobot);
    await prefs.setBool(_kAccessibilityConsent, settings.accessibilityConsent);
    await prefs.setBool(_kScreenActionConsent, settings.screenActionConsent);
  }
}
