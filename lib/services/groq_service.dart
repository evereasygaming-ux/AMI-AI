import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/screen_action.dart';
import 'assistant_action_tools.dart';
import 'ami_system_prompt.dart';
import 'gemini_service.dart' show GeminiException;

class GroqService {
  GroqService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static final _endpoint = Uri.parse(
    'https://api.groq.com/openai/v1/chat/completions',
  );

  Future<AiResponse> generate({
    required String apiKey,
    required String model,
    required List<ChatMessage> history,
    Uint8List? screenshot,
    String localeHint = 'auto',
    bool enableScreenActions = false,
    bool enableDeviceActions = false,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw GeminiException(
        'Add your Groq API key in Settings to chat with AMI.',
      );
    }
    final start = history.length > 18 ? history.length - 18 : 0;
    final actionGuidance = [
      if (enableScreenActions) 'When the user directly requests a screen action, propose at most one tap_at or type_text tool call. The user must approve it before execution.',
      if (enableDeviceActions)
        'When the user directly requests a device action, propose at most one available device action. It will run only after explicit user approval. Current local date and time: ${DateTime.now().toLocal().toIso8601String()}; UTC offset minutes: ${DateTime.now().timeZoneOffset.inMinutes}. Use this to calculate reminder delay_minutes.',
    ].join('\n');
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content':
            AmiSystemPrompt.text +
            (actionGuidance.isEmpty ? '' : '\n$actionGuidance'),
      },
    ];
    for (final message in history.skip(start)) {
      final text = message.text.trim();
      if (text.isEmpty && !(message.isUser && screenshot != null)) continue;
      final isLatestUser = identical(message, history.last) && message.isUser;
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
      } else {
        messages.add({
          'role': message.isUser ? 'user' : 'assistant',
          'content': text,
        });
      }
    }
    if (messages.length == 1) {
      throw GeminiException('Say something first and I will answer.');
    }

    late http.Response response;
    try {
      final payload = <String, dynamic>{
        'model': model.trim().isEmpty ? 'qwen/qwen3.8-27b' : model.trim(),
        'messages': messages,
        'temperature': 0.85,
        'max_tokens': 1200,
      };
      if (enableScreenActions || enableDeviceActions) {
        payload['tools'] = AssistantActionTools.openAi(
          screenActions: enableScreenActions,
          deviceActions: enableDeviceActions,
        );
      }
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 75));
    } catch (_) {
      throw GeminiException(
        'Could not reach Groq. Check your internet connection and try again.',
      );
    }
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}
    if (response.statusCode != 200) {
      final message = data?['error']?['message'] as String?;
      final detail = message == null ? '' : ' $message';
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw GeminiException(
          'Your Groq API key was rejected. Check it in Settings.',
        );
      }
      if (response.statusCode == 429) {
        throw GeminiException(
          'Groq is rate limited right now. Wait a moment and try again.',
        );
      }
      throw GeminiException(
        'Groq request failed (${response.statusCode}).$detail',
      );
    }
    final responseMessage =
        (data?['choices'] as List?)?.firstOrNull?['message'];
    final text = responseMessage is Map ? responseMessage['content'] : null;
    AssistantAction? action;
    final calls = responseMessage is Map
        ? responseMessage['tool_calls'] as List?
        : null;
    final call = calls?.firstOrNull;
    if (call is Map && call['function'] is Map) {
      final function = call['function'] as Map;
      final name = function['name'];
      try {
        final args = jsonDecode(function['arguments'] as String) as Map;
        if (name is String && AssistantAction.supports(name)) {
          action = AssistantAction(
            name: name,
            arguments: args.map((k, v) => MapEntry('$k', v)),
          );
        }
      } catch (_) {}
    }
    if ((text is! String || text.trim().isEmpty) && action == null) {
      throw GeminiException('Groq returned an empty answer. Try again.');
    }
    return AiResponse(text: text is String ? text.trim() : '', action: action);
  }
}
