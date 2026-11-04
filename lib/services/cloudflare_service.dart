import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/screen_action.dart';
import 'assistant_action_tools.dart';
import 'ami_system_prompt.dart';
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
    bool enableDeviceActions = false,
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
      if (enableScreenActions || enableDeviceActions) {
        payload['tools'] = AssistantActionTools.openAi(
          screenActions: enableScreenActions,
          deviceActions: enableDeviceActions,
        );
      }
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
      throw GeminiException(
        'Cloudflare AI returned an empty answer. Try again.',
      );
    }
    return AiResponse(text: text is String ? text.trim() : '', action: action);
  }
}
