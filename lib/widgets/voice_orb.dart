import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ami_controller.dart';
import '../app_theme.dart';

class VoiceOrb extends StatefulWidget {
  const VoiceOrb({
    super.key,
    required this.activity,
    required this.level,
    required this.onTap,
    this.enabled = true,
    this.size = 270,
  });

  final AmiActivity activity;
  final double level;
  final VoidCallback onTap;
  final bool enabled;
  final double size;

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  (Color, Color) get _colors => switch (widget.activity) {
        AmiActivity.listening => (AmiColors.pink, AmiColors.violet),
        AmiActivity.thinking => (AmiColors.violet, AmiColors.cyan),
        AmiActivity.speaking => (AmiColors.mint, AmiColors.cyan),
        AmiActivity.idle => (AmiColors.cyan, AmiColors.violet),
      };

  IconData get _icon => switch (widget.activity) {
        AmiActivity.listening => Icons.mic_rounded,
        AmiActivity.thinking => Icons.auto_awesome_rounded,
        AmiActivity.speaking => Icons.volume_up_rounded,
        AmiActivity.idle => Icons.graphic_eq_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final (primary, secondary) = _colors;
    final dimension = widget.size + 80;
    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: dimension,
        height: dimension,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => CustomPaint(
            painter: _OrbPainter(
              phase: _controller.value,
              activity: widget.activity,
              level: widget.level,
              primary: primary,
              secondary: secondary,
            ),
            child: child,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: Icon(
                _icon,
                key: ValueKey(_icon),
                size: widget.size * 0.2,
                color: Colors.white.withValues(alpha: .92),
                shadows: [
                  Shadow(
                    color: primary.withValues(alpha: .8),
                    blurRadius: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.phase,
    required this.activity,
    required this.level,
    required this.primary,
    required this.secondary,
  });

  final double phase;
  final AmiActivity activity;
  final double level;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.shortestSide * 0.30;
    final t = phase * 2 * math.pi;
    final active = activity != AmiActivity.idle;
    final breathe = 1 + 0.03 * math.sin(t);
    final listen =
        activity == AmiActivity.listening ? 0.14 * level : (active ? 0.02 : 0);
    final radius = base * (breathe + listen);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          primary.withValues(alpha: active ? .34 : .24),
          primary.withValues(alpha: .07),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: base * 2.2));
    canvas.drawCircle(center, base * 2.2, glow);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * 0.3);
    final arcRect = Rect.fromCircle(center: Offset.zero, radius: radius + 18);
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          primary.withValues(alpha: .9),
          secondary.withValues(alpha: .4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.72, 1.0],
      ).createShader(arcRect);
    canvas.drawArc(arcRect, 0.2, math.pi * 1.25, false, arcPaint);
    canvas.restore();

    for (var i = 0; i < 3; i++) {
      final angle = t * (0.35 + i * 0.05) + i * (math.pi * 2 / 3);
      final orbit = radius + 44 + i * 7;
      final dot = center +
          Offset(math.cos(angle) * orbit, math.sin(angle) * orbit * 0.9);
      canvas.drawCircle(
        dot,
        1.6 + i * .6,
        Paint()
          ..color = (i == 1 ? secondary : primary)
              .withValues(alpha: active ? .7 : .4),
      );
    }

    for (var i = 0; i < 2; i++) {
      final ringRadius = radius + 20 + i * 17 + 3 * math.sin(t + i);
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = primary.withValues(alpha: .16 - i * .05),
      );
    }

    if (activity == AmiActivity.listening ||
        activity == AmiActivity.speaking) {
      final pulse = (math.sin(t * 2.2) + 1) / 2;
      canvas.drawCircle(
        center,
        radius + 28 + pulse * 26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = secondary.withValues(alpha: .28 * (1 - pulse)),
      );
    }

    final sphereRect = Rect.fromCircle(center: center, radius: radius);
    final sphere = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.42),
        radius: 1.02,
        colors: [
          Color.lerp(Colors.white, primary, .55)!,
          primary,
          secondary,
          const Color(0xFF140B31),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ).createShader(sphereRect);
    canvas.drawCircle(center, radius, sphere);

    final core = Paint()
      ..shader = RadialGradient(
        colors: [secondary.withValues(alpha: .5), Colors.transparent],
      ).createShader(
        Rect.fromCircle(
          center: center + Offset(radius * .22, radius * .3),
          radius: radius * .95,
        ),
      );
    canvas.drawCircle(center, radius * .97, core);

    canvas.drawCircle(
      center + Offset(-radius * .33, -radius * .37),
      radius * .17,
      Paint()
        ..color = Colors.white.withValues(alpha: .34)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .06),
    );

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = Colors.white.withValues(alpha: .2),
    );

    if (activity == AmiActivity.listening) {
      final barPaint = Paint()
        ..color = Colors.white.withValues(alpha: .88)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 5; i++) {
        final wave = (math.sin(t * 3 + i * 1.2) + 1) / 2;
        final barHeight = 6 + 26 * level * (0.35 + 0.65 * wave);
        final dx = center.dx + (i - 2) * 9.0;
        final cy = center.dy + radius * 0.42;
        canvas.drawLine(
          Offset(dx, cy - barHeight / 2),
          Offset(dx, cy + barHeight / 2),
          barPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.activity != activity ||
      oldDelegate.level != level ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}
