import 'dart:async';

import 'package:flutter/material.dart';

import '../ami_controller.dart';
import '../app_theme.dart';
import '../models/chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.controller});

  final AmiController controller;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _lastCount = widget.controller.messages.length;
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChanged() {
    final count = widget.controller.messages.length;
    if (count != _lastCount) {
      _lastCount = count;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  void _scrollToEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty || widget.controller.isThinking) return;
    _input.clear();
    unawaited(widget.controller.sendMessage(text));
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final messages = controller.messages;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
          child: Row(
            children: [
              const Text(
                'Conversation',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              if (controller.isThinking)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: controller.clearChat,
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Clear', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: AmiColors.muted),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            itemCount:
                messages.length +
                (controller.isThinking ? 1 : 0) +
                (messages.length <= 1 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < messages.length) {
                final message = messages[index];
                return _MessageBubble(
                  message: message,
                  speaking:
                      controller.isSpeaking &&
                      controller.messages.last == message,
                  onSpeak: () => controller.speakMessage(message.text),
                );
              }
              if (controller.isThinking && index == messages.length) {
                return const _TypingBubble();
              }
              return _Suggestions(
                onPick: (text) {
                  unawaited(controller.sendMessage(text));
                },
              );
            },
          ),
        ),
        if (controller.pendingScreenAction != null)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AmiColors.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AmiColors.cyan.withValues(alpha: .45)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AMI wants your approval',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  controller.pendingScreenAction!.description,
                  style: const TextStyle(fontSize: 12, color: AmiColors.muted),
                ),
                const SizedBox(height: 9),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: controller.cancelPendingScreenAction,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: controller.approvePendingScreenAction,
                      child: const Text('Approve this action'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        _Composer(controller: controller, input: _input, onSend: _send),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.speaking,
    required this.onSpeak,
  });

  final ChatMessage message;
  final bool speaking;
  final VoidCallback onSpeak;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final error = message.isError;
    final borderColor = error
        ? AmiColors.pink.withValues(alpha: .35)
        : isUser
        ? AmiColors.cyan.withValues(alpha: .25)
        : Colors.white.withValues(alpha: .06);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
          gradient: isUser
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AmiColors.cyan.withValues(alpha: .18),
                    AmiColors.violet.withValues(alpha: .24),
                  ],
                )
              : null,
          color: isUser ? null : AmiColors.panel,
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (message.image != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(19),
                ),
                child: Stack(
                  children: [
                    Image.memory(
                      message.image!,
                      width: 320,
                      height: 180,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.screen_share_rounded,
                              size: 11,
                              color: Colors.white70,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'screen',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                15,
                message.image != null ? 11 : 14,
                15,
                isUser ? 14 : 6,
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: error ? const Color(0xFFFFB3C6) : AmiColors.text,
                ),
              ),
            ),
            if (!isUser && !error)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onSpeak,
                      visualDensity: VisualDensity.compact,
                      iconSize: 16,
                      color: speaking ? AmiColors.cyan : AmiColors.muted,
                      icon: Icon(
                        speaking
                            ? Icons.stop_circle_outlined
                            : Icons.volume_up_outlined,
                      ),
                      tooltip: speaking ? 'Stop' : 'Play aloud',
                    ),
                    Text(
                      _time(message.createdAt),
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AmiColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _time(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AmiColors.panel,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(6),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: .06)),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Opacity(
                  opacity:
                      0.25 +
                      0.75 *
                          ((1 - ((_controller.value - i * .18).abs() % 1))
                              .clamp(0.0, 1.0)),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AmiColors.cyan,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onPick});

  final ValueChanged<String> onPick;

  static const _items = [
    'What can you do?',
    'Read my screen and explain it',
    'Summarize what you see',
    'Help me reply to this message',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in _items)
            ActionChip(
              label: Text(item, style: const TextStyle(fontSize: 11.5)),
              onPressed: () => onPick(item),
              backgroundColor: AmiColors.panel,
              side: BorderSide(color: AmiColors.cyan.withValues(alpha: .18)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.input,
    required this.onSend,
  });

  final AmiController controller;
  final TextEditingController input;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      decoration: BoxDecoration(
        color: AmiColors.bg.withValues(alpha: .6),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: .05)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (controller.screenActive)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Row(
                children: [
                  if (controller.lastFrame != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        controller.lastFrame!,
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  if (controller.lastFrame != null) const SizedBox(width: 9),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AmiColors.mint,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Expanded(
                    child: Text(
                      'Screen context on — AMI will see your screen with this message.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: AmiColors.muted),
                    ),
                  ),
                  GestureDetector(
                    onTap: controller.toggleScreenShare,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        'Stop',
                        style: TextStyle(
                          fontSize: 11,
                          color: AmiColors.pink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: AmiColors.panel,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: .07)),
            ),
            padding: const EdgeInsets.fromLTRB(4, 4, 5, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: controller.screenBusy
                      ? null
                      : controller.toggleScreenShare,
                  icon: Icon(
                    controller.screenActive
                        ? Icons.screen_share_rounded
                        : Icons.screen_share_outlined,
                    size: 20,
                    color: controller.screenActive
                        ? AmiColors.mint
                        : AmiColors.muted,
                  ),
                  tooltip: 'Screen context',
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: TextField(
                    controller: input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(fontSize: 14.5),
                    decoration: const InputDecoration(
                      hintText: 'Message AMI…',
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: controller.toggleVoice,
                  icon: Icon(
                    controller.isListening
                        ? Icons.mic_rounded
                        : Icons.mic_none_rounded,
                    size: 21,
                    color: controller.isListening
                        ? AmiColors.pink
                        : AmiColors.muted,
                  ),
                  tooltip: 'Voice',
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 42,
                  height: 42,
                  child: controller.isThinking
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton.filled(
                          onPressed: onSend,
                          icon: const Icon(
                            Icons.arrow_upward_rounded,
                            size: 20,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AmiColors.cyan.withValues(
                              alpha: .18,
                            ),
                            foregroundColor: AmiColors.cyan,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
