import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ami_controller.dart';
import '../app_theme.dart';
import '../widgets/voice_orb.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onOpenSettings,
    required this.onOpenChat,
  });

  final AmiController controller;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    final activity = controller.activity;
    final status = switch (activity) {
      AmiActivity.listening => 'Listening…',
      AmiActivity.thinking => 'Thinking…',
      AmiActivity.speaking => 'Speaking…',
      AmiActivity.idle => 'Tap to talk',
    };
    final subtitle = switch (activity) {
      AmiActivity.listening => controller.transcript.isEmpty
          ? "I'm all ears. Say what you need."
          : controller.transcript,
      AmiActivity.thinking =>
        'Reading the moment and putting an answer together.',
      AmiActivity.speaking => 'Tap the orb to stop my voice.',
      AmiActivity.idle => controller.transcript.isEmpty
          ? 'Ask me anything — or let me look at your screen.'
          : controller.transcript,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final orbSize = math.min(constraints.maxWidth - 80.0, 272.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(
                controller: controller,
                onOpenSettings: onOpenSettings,
              ),
              const SizedBox(height: 10),
              Center(
                child: VoiceOrb(
                  activity: activity,
                  level: controller.soundLevel,
                  size: orbSize,
                  enabled: !controller.isThinking,
                  onTap: controller.toggleVoice,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w600,
                  color: activity == AmiActivity.idle
                      ? AmiColors.muted
                      : AmiColors.cyan,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: AmiColors.text,
                ),
              ),
              if (controller.captureCountdown > 0) ...[
                const SizedBox(height: 16),
                _CountdownCard(seconds: controller.captureCountdown),
              ],
              if (controller.notice != null) ...[
                const SizedBox(height: 14),
                _NoticeCard(
                  text: controller.notice!,
                  onClose: controller.clearNotice,
                ),
              ],
              if (!controller.hasApiKey) ...[
                const SizedBox(height: 16),
                _SetupCard(onTap: onOpenSettings),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.screen_search_desktop_rounded,
                      label: 'Look at\nanother app',
                      onTap: controller.lookAtScreenIn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.center_focus_strong_rounded,
                      label: 'Read my\nscreen now',
                      onTap: controller.analyzeScreenNow,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Open\nchat',
                      onTap: onOpenChat,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ScreenContextCard(controller: controller),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.onOpenSettings});

  final AmiController controller;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AmiColors.cyan, AmiColors.violet],
            ),
            boxShadow: [
              BoxShadow(
                color: AmiColors.cyan.withValues(alpha: .28),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(Icons.graphic_eq_rounded, size: 20),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AMI',
              style: TextStyle(
                fontSize: 18,
                letterSpacing: 4,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'AI Multimodal Intelligence',
              style: TextStyle(fontSize: 9, color: AmiColors.muted),
            ),
          ],
        ),
        const Spacer(),
        _ScreenPill(controller: controller),
        const SizedBox(width: 4),
        IconButton(
          onPressed: onOpenSettings,
          icon: const Icon(Icons.settings_outlined, size: 21),
          color: AmiColors.muted,
        ),
      ],
    );
  }
}

class _ScreenPill extends StatelessWidget {
  const _ScreenPill({required this.controller});

  final AmiController controller;

  @override
  Widget build(BuildContext context) {
    final active = controller.screenActive;
    final busy = controller.screenBusy;
    return GestureDetector(
      onTap: busy ? null : controller.toggleScreenShare,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? AmiColors.mint.withValues(alpha: .1)
              : AmiColors.panel,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: active
                ? AmiColors.mint.withValues(alpha: .4)
                : Colors.white.withValues(alpha: .08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? AmiColors.mint : AmiColors.muted,
                ),
              ),
            const SizedBox(width: 6),
            Text(
              active ? 'Screen on' : 'Screen off',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: active ? AmiColors.mint : AmiColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.seconds});

  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AmiColors.violet.withValues(alpha: .18),
            AmiColors.cyan.withValues(alpha: .08),
          ],
        ),
        border: Border.all(color: AmiColors.violet.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AmiColors.violet.withValues(alpha: .2),
            ),
            child: Text(
              '$seconds',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AmiColors.text,
              ),
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Switch to the app you want me to see',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                SizedBox(height: 3),
                Text(
                  'I will take a look when the countdown ends. Keep screen context on.',
                  style: TextStyle(fontSize: 11.5, color: AmiColors.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.text, required this.onClose});

  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AmiColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AmiColors.cyan.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, size: 17, color: AmiColors.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.4),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 17),
            color: AmiColors.muted,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AmiColors.violet.withValues(alpha: .2),
            AmiColors.cyan.withValues(alpha: .07),
          ],
        ),
        border: Border.all(color: AmiColors.violet.withValues(alpha: .38)),
      ),
      child: Row(
        children: [
          const Icon(Icons.key_rounded, color: AmiColors.violet, size: 22),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Connect Gemini',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                SizedBox(height: 3),
                Text(
                  'Paste your API key to wake AMI up.',
                  style: TextStyle(fontSize: 11.5, color: AmiColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: AmiColors.violet,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Set up', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: glassPanel(radius: 18),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AmiColors.cyan.withValues(alpha: .1),
              ),
              child: Icon(icon, size: 18, color: AmiColors.cyan),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                height: 1.3,
                color: AmiColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreenContextCard extends StatelessWidget {
  const _ScreenContextCard({required this.controller});

  final AmiController controller;

  @override
  Widget build(BuildContext context) {
    final active = controller.screenActive;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassPanel(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (active ? AmiColors.mint : AmiColors.muted)
                      .withValues(alpha: .12),
                ),
                child: Icon(
                  Icons.screen_share_rounded,
                  size: 17,
                  color: active ? AmiColors.mint : AmiColors.muted,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active ? 'Screen context is on' : 'Screen context is off',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      active
                          ? 'AMI can read what is on your screen when you ask.'
                          : 'Share your screen so AMI can read any app with you.',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AmiColors.muted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: active
                ? OutlinedButton.icon(
                    onPressed: controller.screenBusy
                        ? null
                        : controller.toggleScreenShare,
                    icon: const Icon(Icons.stop_circle_outlined, size: 17),
                    label: const Text('Stop screen context'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AmiColors.pink,
                      side: BorderSide(
                        color: AmiColors.pink.withValues(alpha: .35),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: controller.screenBusy
                        ? null
                        : controller.toggleScreenShare,
                    icon: controller.screenBusy
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 1.7),
                          )
                        : const Icon(Icons.screen_share_rounded, size: 17),
                    label: Text(
                      controller.screenBusy
                          ? 'Opening screen sharing…'
                          : 'Turn on screen context',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AmiColors.cyan.withValues(alpha: .16),
                      foregroundColor: AmiColors.cyan,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
          ),
          if (active) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: AmiColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Screenshots are sent to Gemini only when you ask a question.',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AmiColors.muted.withValues(alpha: .9),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
