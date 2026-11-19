import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/live/domain/live_phase.dart';

/// The glowing button. It breathes when idle, glows while listening, spins
/// while thinking, pulses while speaking, and grows with the voice [level].
class Orb extends StatefulWidget {
  const Orb({required this.phase, required this.level, super.key});

  final LivePhase phase;
  final double level;

  @override
  State<Orb> createState() => _OrbState();
}

class _OrbState extends State<Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void didUpdateWidget(Orb old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase) {
      _c.duration = switch (widget.phase) {
        LivePhase.idle => const Duration(seconds: 4),
        LivePhase.listening => const Duration(milliseconds: 2200),
        LivePhase.thinking => const Duration(milliseconds: 1100),
        LivePhase.speaking => const Duration(milliseconds: 800),
      };
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: true,
      label: 'Talk to Grid',
      child: SizedBox(
        width: 128,
        height: 128,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = reduce ? 0.0 : _c.value;
            final wave = math.sin(t * 2 * math.pi);
            final scale = switch (widget.phase) {
              LivePhase.idle || LivePhase.listening => 1 + 0.035 * (wave + 1),
              LivePhase.speaking => 1 + 0.07 * (wave + 1),
              LivePhase.thinking => 1.0,
            };
            final grow = 1 + widget.level * 0.35;
            return Transform.scale(
              scale: grow,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.phase == LivePhase.listening ||
                      widget.phase == LivePhase.speaking)
                    Transform.scale(
                      scale: 0.9 + 0.6 * t,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: GridColors.accent2.withValues(
                              alpha: 0.5 * (1 - t),
                            ),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  Transform.scale(
                    scale: scale,
                    child: Transform.rotate(
                      angle: widget.phase == LivePhase.thinking
                          ? t * 2 * math.pi
                          : 0,
                      child: _ball(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _ball() {
    final thinking = widget.phase == LivePhase.thinking;
    final glow = switch (widget.phase) {
      LivePhase.listening => GridColors.accent2.withValues(alpha: 0.6),
      LivePhase.speaking => GridColors.accent.withValues(alpha: 0.8),
      _ => GridColors.accent.withValues(alpha: 0.55),
    };
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: thinking
            ? const SweepGradient(
                colors: [
                  GridColors.accent,
                  GridColors.accent2,
                  Color(0xFFBFE3FF),
                  GridColors.accent,
                ],
              )
            : const RadialGradient(
                center: Alignment(-0.4, -0.45),
                radius: 1.0,
                colors: [Color(0xFFBFE3FF), GridColors.accent, GridColors.accent2],
                stops: [0, 0.48, 0.95],
              ),
        boxShadow: [BoxShadow(color: glow, blurRadius: 38)],
      ),
    );
  }
}
