class AssistantAction {
  const AssistantAction({required this.name, required this.arguments});

  static const supportedNames = {
    'tap_at',
    'type_text',
    'create_note',
    'remind_after',
    'launch_app',
    'open_settings_page',
  };

  static bool supports(String name) => supportedNames.contains(name);

  final String name;
  final Map<String, dynamic> arguments;

  String get description => switch (name) {
    'tap_at' =>
      'स्क्रीन पर ${_percent('x')}% दाएँ और ${_percent('y')}% नीचे टैप करें',
    'type_text' => 'फ़ोकस किए गए फ़ील्ड में “${arguments['text']}” लिखें',
    'create_note' =>
      'इस फ़ोन में “${arguments['title']}” नाम का नोट सेव करें:\n${arguments['content']}',
    'remind_after' => '$_reminderDelay याद दिलाएँ: ${arguments['title']}',
    'launch_app' => '${arguments['app_name']} ऐप खोलें',
    'open_settings_page' => 'सेटिंग्स में $_settingsPageName पेज खोलें',
    _ => 'अनजान कार्रवाई',
  };

  String get _settingsPageName => switch (arguments['page']) {
    'wifi' => 'वाई-फ़ाई',
    'bluetooth' => 'ब्लूटूथ',
    'display' => 'डिस्प्ले',
    'sound' => 'साउंड',
    'location' => 'लोकेशन',
    'notifications' => 'नोटिफ़िकेशन',
    'apps' => 'ऐप्स',
    'battery' => 'बैटरी',
    'accessibility' => 'ऐक्सेसिबिलिटी',
    'language' => 'भाषा',
    _ => 'चुनी हुई सेटिंग्स',
  };

  String get _reminderDelay {
    final rawMinutes = arguments['delay_minutes'];
    final minutes = rawMinutes is num ? rawMinutes.toInt() : 0;
    if (minutes < 60) return '$minutes मिनट बाद';
    if (minutes % 1440 == 0) return '${minutes ~/ 1440} दिन बाद';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0
        ? '$hours घंटे बाद'
        : '$hours घंटे $remainingMinutes मिनट बाद';
  }

  int _percent(String key) {
    final value = arguments[key];
    if (value is! num || !value.isFinite) return 0;
    return (value.toDouble() * 100).round().clamp(0, 100).toInt();
  }
}

class AiResponse {
  const AiResponse({this.text = '', this.action});

  final String text;
  final AssistantAction? action;
}
