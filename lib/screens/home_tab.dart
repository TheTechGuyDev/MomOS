import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/game_service.dart';
import '../core/levels.dart';
import '../core/profile_service.dart';
import '../core/quests.dart';
import '../core/theme.dart';
import '../widgets/celebration.dart';
import 'achievements_screen.dart';

class HomeTab extends StatefulWidget {
  final Profile profile;
  const HomeTab({super.key, required this.profile});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  GameStats? _stats;
  Family? _family;
  List<Profile> _members = [];
  List<AppBadge> _badges = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        GameService.stats(),
        ProfileService.myFamily(widget.profile.familyId),
        GameService.allBadges(),
      ]);
      final fam = results[1] as Family?;
      final members = fam == null ? <Profile>[] : await ProfileService.familyMembers(fam.id);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as GameStats;
        _family = fam;
        _badges = results[2] as List<AppBadge>;
        _members = members;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your day. Pull down to retry.';
      });
    }
  }

  Future<void> _handleResult(Future<XpResult> Function() action) async {
    if (_busy || _stats == null) return;
    setState(() => _busy = true);
    final oldLevel = LevelInfo.fromXp(_stats!.xp).level;
    try {
      final r = await action();
      HapticFeedback.mediumImpact();
      await _load();
      if (!mounted) return;
      showXpToast(context, r.gained);
      final info = LevelInfo.fromXp(r.xp);
      final newBadges = _badges.where((b) => r.newBadges.contains(b.key)).toList();
      if (info.level > oldLevel || newBadges.isNotEmpty) {
        await showCelebration(
          context,
          newLevel: info.level > oldLevel ? info.level : null,
          levelTitle: info.title,
          badges: newBadges,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That did not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final p = widget.profile;
    final s = _stats;
    final quests = questsForDay(lagosToday());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _Header(greeting: _greeting, profile: p),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: t.bodyMedium?.copyWith(color: Colors.red.shade400)),
          ],
          if (s != null) ...[
            const SizedBox(height: 20),
            _LevelCard(
              stats: s,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AchievementsScreen(stats: s, badges: _badges),
              )),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    emoji: '🔥',
                    value: '${s.currentStreak}',
                    label: 'day streak',
                    color: AppColors.sun,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    emoji: '⭐',
                    value: '${s.xpToday}',
                    label: 'XP today',
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    emoji: '🏅',
                    value: '${s.badges.length}/${_badges.length}',
                    label: 'badges',
                    color: AppColors.mint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _CheckInCard(
              done: s.checkedInToday,
              busy: _busy,
              onTap: () => _handleResult(GameService.checkIn),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text("Today's quests", style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('${s.questsDoneToday.length}/4 done',
                    style: t.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Finish all 4 for a +25 XP bonus',
                style: t.bodySmall?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 10),
            ...quests.map((q) => _QuestTile(
                  quest: q,
                  done: s.questsDoneToday.contains(q.key),
                  onTap: () => _handleResult(() => GameService.completeQuest(q.key)),
                )),
          ],
          if (_family != null) ...[
            const SizedBox(height: 24),
            _FamilyCard(family: _family!, members: _members, myId: p.id),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String greeting;
  final Profile profile;
  const _Header({required this.greeting, required this.profile});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(profile.avatar, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
              Text(profile.displayName, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Sign out',
          onPressed: () => supa.auth.signOut(),
          icon: const Icon(Icons.logout),
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  final GameStats stats;
  final VoidCallback onTap;
  const _LevelCard({required this.stats, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final info = LevelInfo.fromXp(stats.xp);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.3),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Level ${info.level} · ${info.title}',
                          style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${stats.xp} XP',
                          style: t.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const Text('🏆', style: TextStyle(fontSize: 44)),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: info.progress),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('${info.xpToNext} XP to Level ${info.level + 1}',
                    style: t.bodySmall?.copyWith(color: Colors.white70, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('Achievements ›',
                    style: t.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String emoji, value, label;
  final Color color;
  const _StatTile({required this.emoji, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
          Text(label, style: t.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  final bool done, busy;
  final VoidCallback onTap;
  const _CheckInCard({required this.done, required this.busy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: done ? AppColors.mint.withValues(alpha: 0.15) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: done ? AppColors.mint : const Color(0xFFF0E6E9)),
      ),
      child: Row(
        children: [
          Text(done ? '✅' : '☀️', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(done ? 'Checked in today' : 'Daily check-in',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                Text(done ? 'See you tomorrow to keep your streak' : 'Tap to start your day and earn +10 XP',
                    style: t.bodySmall?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          if (!done)
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(80, 44)),
              onPressed: busy ? null : onTap,
              child: const Text('Check in'),
            ),
        ],
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  final Quest quest;
  final bool done;
  final VoidCallback onTap;
  const _QuestTile({required this.quest, required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: done ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: done ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(quest.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quest.title,
                        style: t.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? AppColors.muted : AppColors.ink,
                        ),
                      ),
                      Text(quest.hint, style: t.bodySmall?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: done
                      ? const Icon(Icons.check_circle, color: AppColors.mint, key: ValueKey('d'), size: 28)
                      : Container(
                          key: const ValueKey('n'),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.sun.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('+15', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w900)),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FamilyCard extends StatelessWidget {
  final Family family;
  final List<Profile> members;
  final String myId;
  const _FamilyCard({required this.family, required this.members, required this.myId});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏡', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(family.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    Text('Family code: ${family.inviteCode}',
                        style: t.bodySmall?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: family.inviteCode));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Family code copied')));
                },
              ),
            ],
          ),
          if (members.isNotEmpty) ...[
            const Divider(height: 24),
            ...members.map((m) {
              final lvl = LevelInfo.fromXp(m.xp);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(m.avatar, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(m.id == myId ? '${m.displayName} (you)' : m.displayName,
                          style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Text('Lv ${lvl.level} · ${m.xp} XP',
                        style: t.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
