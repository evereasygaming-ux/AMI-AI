class ScreenAction {
  const ScreenAction({required this.name, required this.arguments});

  final String name;
  final Map<String, dynamic> arguments;

  String get description => switch (name) {
    'tap_at' =>
      'Tap the screen near ${(arguments['x'] as num? ?? 0).toDouble() * 100 ~/ 1}% across and ${(arguments['y'] as num? ?? 0).toDouble() * 100 ~/ 1}% down',
    'type_text' => 'Enter “${arguments['text']}” in the focused field',
    _ => 'Unknown screen action',
  };
}

class AiResponse {
  const AiResponse({this.text = '', this.action});

  final String text;
  final ScreenAction? action;
}
