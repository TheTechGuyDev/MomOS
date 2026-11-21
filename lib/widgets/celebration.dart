import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../core/game_service.dart';
import '../core/theme.dart';

/// Small "+XP" toast that floats up from the bottom.
void showXpToast(BuildContext context, int gained) {
  if (gained <= 0) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppColors.ink,
      duration: const Duration(milliseconds: 1600),
      content: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text('+$gained XP',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    ),
  );
}

/// Full-screen celebration for a level up or new badges.
Future<void> showCelebration(
  BuildContext context, {
  int? newLevel,
  String? levelTitle,
  List<AppBadge> badges = const [],
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'close',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (context, _, _) => _CelebrationCard(
      newLevel: newLevel,
      levelTitle: levelTitle,
      badges: badges,
    ),
    transitionBuilder: (context, anim, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
      child: FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _CelebrationCard extends StatefulWidget {
  final int? newLevel;
  final String? levelTitle;
  final List<AppBadge> badges;
  const _CelebrationCard({this.newLevel, this.levelTitle, required this.badges});
  @override
  State<_CelebrationCard> createState() => _CelebrationCardState();
}

class _CelebrationCardState extends State<_CelebrationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isLevel = widget.newLevel != null;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: IgnorePointer(child: _Confetti(controller: _c))),
        Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isLevel ? '🎉' : widget.badges.first.emoji,
                    style: const TextStyle(fontSize: 64)),
                const SizedBox(height: 8),
                Text(
                  isLevel ? 'Level ${widget.newLevel}!' : 'New badge!',
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                if (isLevel)
                  Text('You are now a ${widget.levelTitle}',
                      textAlign: TextAlign.center,
                      style: t.bodyLarge?.copyWith(color: AppColors.muted)),
                if (widget.badges.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: widget.badges
                        .map((b) => Chip(
                              avatar: Text(b.emoji),
                              label: Text(b.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800)),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Yay!'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Confetti extends StatelessWidget {
  final AnimationController controller;
  const _Confetti({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(painter: _ConfettiPainter(controller.value)),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);
  static final _rand = Random(7);
  static final _pieces = List.generate(
    70,
    (_) => [_rand.nextDouble(), _rand.nextDouble(), _rand.nextDouble(), _rand.nextInt(5).toDouble()],
  );
  static const _colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.mint,
    AppColors.sun,
    AppColors.sky,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _pieces) {
      final x = p[0] * size.width + sin((t * 6) + p[1] * 10) * 20;
      final y = (p[1] * -0.5 + t * (0.9 + p[2])) * size.height;
      final paint = Paint()..color = _colors[p[3].toInt()].withValues(alpha: 1 - t * 0.6);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 10 * p[2]);
      canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -7, 8, 14), const Radius.circular(2)),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
