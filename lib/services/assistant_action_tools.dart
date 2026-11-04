class AssistantActionTools {
  static List<Map<String, dynamic>> gemini({
    required bool screenActions,
    required bool deviceActions,
  }) => [
    {
      'function_declarations': [
        if (screenActions) ..._screenDeclarations.map(_geminiDeclaration),
        if (deviceActions) ..._deviceDeclarations.map(_geminiDeclaration),
      ],
    },
  ];

  static List<Map<String, dynamic>> openAi({
    required bool screenActions,
    required bool deviceActions,
  }) => [
    if (screenActions)
      for (final declaration in _screenDeclarations)
        {'type': 'function', 'function': declaration},
    if (deviceActions)
      for (final declaration in _deviceDeclarations)
        {'type': 'function', 'function': declaration},
  ];

  static const _screenDeclarations = [
    {
      'name': 'tap_at',
      'description': 'Propose one tap on a visible screen control only when directly requested by the user.',
      'parameters': {
        'type': 'object',
        'properties': {
          'x': {
            'type': 'number',
            'description': 'Horizontal fraction from 0 (left) to 1 (right).',
          },
          'y': {
            'type': 'number',
            'description': 'Vertical fraction from 0 (top) to 1 (bottom).',
          },
        },
        'required': ['x', 'y'],
      },
    },
    {
      'name': 'type_text',
      'description': 'Propose entering the exact user-requested text in the focused non-password field.',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {
            'type': 'string',
            'description': 'Exact text requested by the user.',
          },
        },
        'required': ['text'],
      },
    },
  ];

  static const _deviceDeclarations = [
    {
      'name': 'create_note',
      'description': 'Save a note locally on this phone, only when the user asks to save or remember information.',
      'parameters': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'content': {'type': 'string'},
        },
        'required': ['title', 'content'],
      },
    },
    {
      'name': 'remind_after',
      'description': 'Schedule one local notification reminder after the requested duration. Calculate delay_minutes from the current local time supplied in the system instruction.',
      'parameters': {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
          'delay_minutes': {'type': 'integer'},
        },
        'required': ['title', 'delay_minutes'],
      },
    },
    {
      'name': 'launch_app',
      'description': 'Open an installed app by its visible app name, only when directly asked.',
      'parameters': {
        'type': 'object',
        'properties': {
          'app_name': {'type': 'string'},
        },
        'required': ['app_name'],
      },
    },
    {
      'name': 'open_settings_page',
      'description': 'Open the requested Android Settings page. This opens the page for the user; it does not change a setting.',
      'parameters': {
        'type': 'object',
        'properties': {
          'page': {
            'type': 'string',
            'enum': [
              'wifi',
              'bluetooth',
              'display',
              'sound',
              'location',
              'notifications',
              'apps',
              'battery',
              'accessibility',
              'language',
            ],
          },
        },
        'required': ['page'],
      },
    },
  ];

  static Map<String, dynamic> _geminiDeclaration(Map<String, dynamic> raw) =>
      raw.map((key, value) => MapEntry(key, _toGeminiSchema(value)));

  static dynamic _toGeminiSchema(dynamic value) {
    if (value is List) {
      return value.map(_toGeminiSchema).toList();
    }
    if (value is Map) {
      return value.map((key, nested) {
        final normalizedKey = '$key';
        final normalizedValue = normalizedKey == 'type' && nested is String
            ? nested.toUpperCase()
            : _toGeminiSchema(nested);
        return MapEntry(normalizedKey, normalizedValue);
      });
    }
    return value;
  }
}
