import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../widgets/ui.dart';
import 'certificate_screen.dart';
import 'content.dart';
import 'learn_service.dart';
import 'lesson_screen.dart';
import 'portfolio_screen.dart';
import 'sheet_lab.dart';
import 'sql_lab.dart';
import 'tutor_screen.dart';

class LearnTab extends StatefulWidget {
  const LearnTab({super.key});
  @override
  State<LearnTab> createState() => _LearnTabState();
}

class _LearnTabState extends State<LearnTab> {
  Map<String, LessonProgress> _progress = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await LearnService.progress();
      if (mounted) {
        setState(() {
          _progress = p;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Lesson l) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LessonScreen(lesson: l, alreadyDone: _progress.containsKey(l.key)),
    ));
    _load();
  }

  Lesson? get _next {
    for (final t in tracks) {
      for (final l in t.lessons) {
        if (!_progress.containsKey(l.key)) return l;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final totalLessons = tracks.fold<int>(0, (s, tr) => s + tr.lessons.length);
    final done = _progress.length;
    final streak = LearnService.learningStreak(_progress.values);
    final next = _next;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const TabHeader(title: 'Learn', subtitle: 'Data Analysis, 5–10 minutes at a time'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.secondary, Color(0xFF5AA9E6)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Text('Data Analyst Path',
                          style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                    Text('🔥 $streak day${streak == 1 ? '' : 's'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 4),
                  Text('$done of $totalLessons lessons', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: done / totalLessons,
                      minHeight: 8,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink),
                      onPressed: () => _open(next),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(done == 0 ? 'Start: ${next.title}' : 'Continue: ${next.title}', overflow: TextOverflow.ellipsis),
                    ),
                  ] else ...[
                    const SizedBox(height: 10),
                    const Text('🎉 You finished every track!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                  ],
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: [
                _Tool('✨', 'AI tutor', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TutorScreen()))),
                const SizedBox(width: 8),
                _Tool('🗄️', 'SQL Lab', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SqlLabScreen()))),
                const SizedBox(width: 8),
                _Tool('📗', 'Sheet Lab', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SheetLabScreen()))),
                const SizedBox(width: 8),
                _Tool('💼', 'Portfolio', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PortfolioScreen()))),
              ]),
              const SectionTitle('Tracks'),
              ...tracks.map((tr) {
                final n = tr.lessons.where((l) => _progress.containsKey(l.key)).length;
                final complete = n == tr.lessons.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: WhiteCard(
                    padding: EdgeInsets.zero,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        shape: const RoundedRectangleBorder(),
                        leading: Text(tr.emoji, style: const TextStyle(fontSize: 28)),
                        title: Text(tr.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('$n / ${tr.lessons.length} lessons${complete ? ' · Certified 🎓' : ''}',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(value: n / tr.lessons.length, minHeight: 5),
                          ),
                        ]),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                            child: Text(tr.blurb, style: t.bodySmall?.copyWith(color: AppColors.muted)),
                          ),
                          ...tr.lessons.asMap().entries.map((e) {
                            final l = e.value;
                            final p = _progress[l.key];
                            return ListTile(
                              onTap: () => _open(l),
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: p != null ? AppColors.mint : AppColors.primary.withValues(alpha: 0.12),
                                child: p != null
                                    ? const Icon(Icons.check, size: 18, color: Colors.white)
                                    : Text('${e.key + 1}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                              ),
                              title: Text(l.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(p != null ? 'Best score ${p.bestScore}/${p.total}' : '${l.minutes} min'),
                              trailing: const Icon(Icons.chevron_right),
                            );
                          }),
                          if (complete)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  final last = tr.lessons
                                      .map((l) => _progress[l.key]!.completedAt)
                                      .reduce((a, b) => a.isAfter(b) ? a : b);
                                  Navigator.of(context).push(MaterialPageRoute(
                                    builder: (_) => CertificateScreen(track: tr, earnedOn: last),
                                  ));
                                },
                                icon: const Icon(Icons.workspace_premium),
                                label: const Text('View certificate'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  final String emoji, label;
  final VoidCallback onTap;
  const _Tool(this.emoji, this.label, this.onTap);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: WhiteCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      ),
    );
  }
}
