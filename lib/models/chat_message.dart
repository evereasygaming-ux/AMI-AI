import 'dart:typed_data';

enum MessageRole { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    DateTime? createdAt,
    this.image,
    this.isError = false,
  }) : createdAt = createdAt ?? DateTime.now();

  final MessageRole role;
  final String text;
  final DateTime createdAt;
  final Uint8List? image;
  final bool isError;

  bool get isUser => role == MessageRole.user;

  Map<String, dynamic> toGeminiPart() => {'text': text};
}
