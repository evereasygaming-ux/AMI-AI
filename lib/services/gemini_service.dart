import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import '../models/screen_action.dart';
import 'assistant_action_tools.dart';
import 'ami_system_prompt.dart';

class GeminiException implements Exception {
  GeminiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _endpoint = 'https://generativelanguage.googleapis.com/v1beta';

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
        'No Gemini API key yet. Open Settings and paste your key to wake me up.',
      );
    }

    final modelId = model.trim().isEmpty ? 'gemini-3.6-flash' : model.trim();
    final uri = Uri.parse('$_endpoint/models/$modelId:generateContent');

    final contents = <Map<String, dynamic>>[];
    final start = history.length > 18 ? history.length - 18 : 0;
    final recent = history.skip(start).toList();
    for (var i = 0; i < recent.length; i++) {
      final message = recent[i];
      final parts = <Map<String, dynamic>>[];
      if (message.text.trim().isNotEmpty) {
        parts.add({'text': message.text.trim()});
      }
      final isLatestUser =
          i == recent.length - 1 && message.role == MessageRole.user;
      if (isLatestUser && screenshot != null) {
        parts.add({
          'inline_data': {
            'mime_type': 'image/jpeg',
            'data': base64Encode(screenshot),
          },
        });
      }
      if (parts.isEmpty) continue;
      contents.add({'role': message.isUser ? 'user' : 'model', 'parts': parts});
    }

    final normalized = <Map<String, dynamic>>[];
    for (final entry in contents) {
      if (normalized.isEmpty && entry['role'] == 'model') continue;
      if (normalized.isNotEmpty && normalized.last['role'] == entry['role']) {
        (normalized.last['parts'] as List).addAll(entry['parts'] as List);
      } else {
        normalized.add(entry);
      }
    }

    if (normalized.isEmpty) {
      throw GeminiException('Say something first and I will answer.');
    }

    final actionGuidance = [
      if (enableScreenActions) 'When the user directly requests a screen action, propose at most one tap_at or type_text call. The user must approve it before execution.',
      if (enableDeviceActions)
        'When the user directly requests a device action, propose at most one available device action. It will run only after explicit user approval. Current local date and time: ${DateTime.now().toLocal().toIso8601String()}; UTC offset minutes: ${DateTime.now().timeZoneOffset.inMinutes}. Use this to calculate reminder delay_minutes.',
    ].join('\n');

    final body = <String, dynamic>{
      'system_instruction': {
        'parts': [
          {
            'text':
                AmiSystemPrompt.text +
                (actionGuidance.isEmpty ? '' : '\n$actionGuidance'),
          },
        ],
      },
      'contents': normalized,
      'generationConfig': {
        'temperature': 0.85,
        'maxOutputTokens': 1200,
        'topP': 0.95,
      },
    };
    if (enableScreenActions || enableDeviceActions) {
      body['tools'] = AssistantActionTools.gemini(
        screenActions: enableScreenActions,
        deviceActions: enableDeviceActions,
      );
    }

    late http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': key,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 75));
    } catch (_) {
      throw GeminiException(
        'Could not reach Gemini. Check your internet connection and try again.',
      );
    }

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }

    if (response.statusCode != 200) {
      final message = data?['error']?['message'] as String?;
      throw GeminiException(_friendlyError(response.statusCode, message));
    }
    if (data == null) {
      throw GeminiException('Gemini sent an unreadable response. Try again.');
    }

    final feedback = data['promptFeedback'] as Map<String, dynamic>?;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      final blocked = feedback?['blockReason'] as String?;
      if (blocked != null) {
        throw GeminiException(
          'I could not answer that request ($blocked). Try rephrasing it.',
        );
      }
      throw GeminiException('I did not get an answer from Gemini. Try again.');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    final text = (parts ?? [])
        .map((part) => part is Map ? part['text'] : null)
        .whereType<String>()
        .join('\n')
        .trim();

    AssistantAction? action;
    for (final part in parts ?? const []) {
      if (part is! Map || part['functionCall'] is! Map) continue;
      final call = part['functionCall'] as Map;
      final name = call['name'];
      final args = call['args'];
      if (name is String && AssistantAction.supports(name) && args is Map) {
        action = AssistantAction(
          name: name,
          arguments: args.map((key, value) => MapEntry('$key', value)),
        );
        break;
      }
    }
    if (text.isEmpty && action == null) {
      final reason = candidates.first['finishReason'] as String?;
      if (reason == 'SAFETY') {
        throw GeminiException('That request was blocked by safety filters.');
      }
      throw GeminiException('Gemini returned an empty answer. Try again.');
    }

    return AiResponse(text: text, action: action);
  }

  String _friendlyError(int status, String? message) {
    if (status == 400) {
      return 'Gemini rejected the request. Check the model name in Settings. '
              '${message ?? ''}'
          .trim();
    }
    if (status == 401 || status == 403) {
      return 'Your Gemini API key was rejected. Open Settings and paste a valid key.';
    }
    if (status == 404) {
      return 'Model not found. Set the model to gemini-3.6-flash in Settings.';
    }
    if (status == 429) {
      return 'Gemini is rate limited right now. Wait a moment and try again.';
    }
    if (status >= 500) {
      return 'Gemini is having trouble right now. Please try again shortly.';
    }
    return message ?? 'Gemini error ($status). Please try again.';
  }
}
