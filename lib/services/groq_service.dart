import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';
import 'gemini_service.dart' show GeminiException;

class GroqService {
  GroqService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static final _endpoint = Uri.parse(
    'https://api.groq.com/openai/v1/chat/completions',
  );

  Future<String> generate({
    required String apiKey,
    required String model,
    required List<ChatMessage> history,
    Uint8List? screenshot,
    String localeHint = 'auto',
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw GeminiException('Add your Groq API key in Settings to chat with AMI.');
    }
    final start = history.length > 18 ? history.length - 18 : 0;
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': _systemPrompt(localeHint)},
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
        messages.add({'role': message.isUser ? 'user' : 'assistant', 'content': text});
      }
    }
    if (messages.length == 1) {
      throw GeminiException('Say something first and I will answer.');
    }

    late http.Response response;
    try {
      response = await _client.post(
        _endpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $key',
        },
        body: jsonEncode({
          'model': model.trim().isEmpty ? 'qwen/qwen3.8-27b' : model.trim(),
          'messages': messages,
          'temperature': 0.85,
          'max_tokens': 1200,
        }),
      ).timeout(const Duration(seconds: 75));
    } catch (_) {
      throw GeminiException('Could not reach Groq. Check your internet connection and try again.');
    }
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {}
    if (response.statusCode != 200) {
      final message = data?['error']?['message'] as String?;
      final detail = message == null ? '' : ' $message';
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw GeminiException('Your Groq API key was rejected. Check it in Settings.');
      }
      if (response.statusCode == 429) {
        throw GeminiException('Groq is rate limited right now. Wait a moment and try again.');
      }
      throw GeminiException('Groq request failed (${response.statusCode}).$detail');
    }
    final text = (data?['choices'] as List?)?.firstOrNull?['message']?['content'];
    if (text is! String || text.trim().isEmpty) {
      throw GeminiException('Groq returned an empty answer. Try again.');
    }
    return text.trim();
  }

  String _systemPrompt(String localeHint) {
    final language = switch (localeHint) {
      'bn-IN' => 'Reply in Bengali (Bangla) unless the user clearly uses another language.',
      'en-IN' => 'Reply in natural Indian English unless the user uses another language.',
      'en-US' => 'Reply in natural English unless the user uses another language.',
      _ => 'Reply in the same language the user is speaking or writing.',
    };
    return '''You are AMI — AI Multimodal Intelligence — a warm, sharp, slightly playful assistant on the user's Android phone. Keep voice replies short and human, usually 1-4 sentences. Be direct and useful. $language''';
  }
}
