import 'package:material_ui/material_ui.dart';

import '../core/game_service.dart';
import '../core/levels.dart';
import '../core/theme.dart';

class AchievementsScreen extends StatefulWidget {
  final GameStats stats;
  final List<AppBadge> badges;
  const AchievementsScreen({super.key, required this.stats, required this.badges});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late final Future<List<XpEvent>> _history = GameService.recentXp();

  static const _sourceLabels = {
    'checkin': ('☀️', 'Daily check-in'),
    'quest': ('🎯', 'Quest completed'),
    'bonus_all_quests': ('✨', 'All quests bonus'),
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = widget.stats;
    final info = LevelInfo.fromXp(s.xp);

    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Row(
              children: [
                _Ring(progress: info.progress, label: '${info.level}'),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      Text('${s.xp} XP total', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Text('🔥 Best streak: ${s.bestStreak} days',
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Badges', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.badges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, i) {
              final b = widget.badges[i];
              final earned = s.badges.contains(b.key);
              return GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${b.name}: ${b.description}')),
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: earned ? Colors.white : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: earned ? AppColors.sun : const Color(0xFFF0E6E9),
                      width: earned ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Opacity(
                        opacity: earned ? 1 : 0.25,
                        child: Text(b.emoji, style: const TextStyle(fontSize: 34)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        b.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: t.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: earned ? AppColors.ink : AppColors.muted,
                        ),
                      ),
                      if (!earned) const Icon(Icons.lock_outline, size: 14, color: AppColors.muted),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Recent XP', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          FutureBuilder<List<XpEvent>>(
            future: _history,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return Text('No XP yet. Check in on the Home tab to start.',
                    style: t.bodyMedium?.copyWith(color: AppColors.muted));
              }
              return Column(
                children: items.map((e) {
                  final label = _sourceLabels[e.source] ?? ('⭐', e.source);
                  final time = TimeOfDay.fromDateTime(e.createdAt).format(context);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(label.$1, style: const TextStyle(fontSize: 24)),
                    title: Text(label.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${e.createdAt.day}/${e.createdAt.month} at $time'),
                    trailing: Text('+${e.points}',
                        style: t.titleMedium?.copyWith(
                            color: AppColors.mint, fontWeight: FontWeight.w900)),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  final double progress;
  final String label;
  const _Ring({required this.progress, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 8,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            strokeCap: StrokeCap.round,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('LEVEL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.muted)),
                Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
