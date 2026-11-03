import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/screen_action.dart';
import 'gemini_service.dart' show GeminiException;

class CloudflareService {
  CloudflareService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AiResponse> generate({
    required String accountId,
    required String apiToken,
    required String model,
    required List<ChatMessage> history,
    Uint8List? screenshot,
    String localeHint = 'auto',
    bool enableScreenActions = false,
  }) async {
    final account = accountId.trim();
    final token = apiToken.trim();
    if (account.isEmpty || token.isEmpty) {
      throw GeminiException(
        'Add your Cloudflare Account ID and API token in Settings.',
      );
    }
    final uri = Uri.https(
      'api.cloudflare.com',
      '/client/v4/accounts/$account/ai/v1/chat/completions',
    );
    final start = history.length > 18 ? history.length - 18 : 0;
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            _systemPrompt(localeHint) +
            (enableScreenActions
                ? '\nWhen the user explicitly requests a screen action, propose only one tap_at or type_text tool call. Never infer actions. The app will wait for explicit approval before execution.'
                : ''),
      },
    ];
    for (final message in history.skip(start)) {
      final text = message.text.trim();
      final isLatestUser =
          history.isNotEmpty &&
          identical(message, history.last) &&
          message.isUser;
      if (isLatestUser && screenshot != null) {
        messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': text},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,${base64Encode(screenshot)}',
              },
            },
          ],
        });
      } else if (text.isNotEmpty) {
        messages.add({
          'role': message.isUser ? 'user' : 'assistant',
          'content': text,
        });
      }
    }
    late http.Response response;
    try {
      final payload = <String, dynamic>{
        'model': model.trim().isEmpty
            ? '@cf/google/gemma-4-26b-a4b-it'
            : model.trim(),
        'messages': messages,
        'temperature': 0.85,
        'max_tokens': 1200,
      };
      if (enableScreenActions) payload['tools'] = _actionTools;
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 75));
    } catch (_) {
      throw GeminiException(
        'Could not reach Cloudflare AI. Check your internet connection and try again.',
      );
    }
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}
    if (response.statusCode != 200) {
      final error = data?['error']?['message'] as String?;
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw GeminiException(
          'Cloudflare rejected the token or account access. Check your Workers AI token permissions and Account ID.',
        );
      }
      if (response.statusCode == 429) {
        throw GeminiException(
          'Cloudflare AI quota or rate limit reached. Try again after the limit resets.',
        );
      }
      throw GeminiException(
        'Cloudflare AI request failed (${response.statusCode}). ${error ?? ''}'
            .trim(),
      );
    }
    final responseMessage =
        (data?['choices'] as List?)?.firstOrNull?['message'];
    final text = responseMessage is Map ? responseMessage['content'] : null;
    ScreenAction? action;
    final calls = responseMessage is Map
        ? responseMessage['tool_calls'] as List?
        : null;
    final call = calls?.firstOrNull;
    if (call is Map && call['function'] is Map) {
      final function = call['function'] as Map;
      final name = function['name'];
      try {
        final args = jsonDecode(function['arguments'] as String) as Map;
        if (name == 'tap_at' || name == 'type_text') {
          action = ScreenAction(
            name: name as String,
            arguments: args.map((k, v) => MapEntry('$k', v)),
          );
        }
      } catch (_) {}
    }
    if ((text is! String || text.trim().isEmpty) && action == null) {
      throw GeminiException(
        'Cloudflare AI returned an empty answer. Try again.',
      );
    }
    return AiResponse(text: text is String ? text.trim() : '', action: action);
  }

  static const _actionTools = [
    {
      'type': 'function',
      'function': {
        'name': 'tap_at',
        'description': 'Propose one tap on a visible control only when directly requested. x and y are normalized fractions from 0 to 1 across and down the screen.',
        'parameters': {
          'type': 'object',
          'properties': {
            'x': {'type': 'number'},
            'y': {'type': 'number'},
          },
          'required': ['x', 'y'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'type_text',
        'description': 'Propose exact user-requested text for the focused non-password field.',
        'parameters': {
          'type': 'object',
          'properties': {
            'text': {'type': 'string'},
          },
          'required': ['text'],
        },
      },
    },
  ];

  String _systemPrompt(String localeHint) {
    final language = switch (localeHint) {
      'bn-IN' => 'Reply in Bengali (Bangla) unless the user clearly uses another language.',
      'en-IN' => 'Reply in natural Indian English unless the user uses another language.',
      'en-US' =>
        'Reply in natural English unless the user uses another language.',
      _ => 'Reply in the same language the user is speaking or writing.',
    };
    return '''You are AMI — AI Multimodal Intelligence — a warm, sharp, slightly playful assistant on the user's Android phone. Keep voice replies short and human, usually 1-4 sentences. Be direct and useful. $language''';
  }
}
