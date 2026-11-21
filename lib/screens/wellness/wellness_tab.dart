import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../core/time_utils.dart';
import '../../core/wellness_service.dart';
import '../../widgets/ui.dart';
import 'breathing_screen.dart';

class WellnessTab extends StatefulWidget {
  const WellnessTab({super.key});
  @override
  State<WellnessTab> createState() => _WellnessTabState();
}

class _WellnessTabState extends State<WellnessTab> {
  WellnessDay? _day;
  List<MoodLog> _moods = [];
  List<WellnessDay> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([WellnessService.today(), WellnessService.moods(), WellnessService.history(days: 7)]);
      if (!mounted) return;
      setState(() {
        _day = r[0] as WellnessDay;
        _moods = r[1] as List<MoodLog>;
        _history = r[2] as List<WellnessDay>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _xp(int gained, [String? msg]) {
    if (gained > 0) {
      toast(context, '${msg ?? 'Saved'}. +$gained XP');
    } else if (msg != null) {
      toast(context, msg);
    }
  }

  Future<void> _setWater(int n) async {
    final d = _day!;
    setState(() => _day = WellnessDay(d.day, n, d.waterGoal, d.sleepHours, d.sleepQuality, d.breathing, d.gratitude));
    try {
      final (g, row) = await WellnessService.setWater(n);
      if (mounted) setState(() => _day = row);
      if (g > 0) _xp(g, 'Water goal reached 💧');
    } catch (_) {
      _load();
    }
  }

  bool get _lowStretch {
    final recent = _moods.where((m) => DateTime.now().difference(m.at).inDays <= 7).toList();
    if (recent.length < 3) return false;
    final avg = recent.map((m) => m.mood).reduce((a, b) => a + b) / recent.length;
    return avg <= 2.2;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final d = _day;
    final t = Theme.of(context).textTheme;
    final todayMood = _moods.where((m) => isSameDay(m.at, DateTime.now())).firstOrNull;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const TabHeader(title: 'Wellness', subtitle: 'Looking after you, too'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 8),
              // Mood
              WhiteCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('How are you feeling?', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  if (todayMood != null)
                    Text('Last check-in: ${moodFaces[todayMood.mood - 1]} ${moodLabels[todayMood.mood - 1]} at ${clock(todayMood.at)}',
                        style: t.bodySmall?.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(5, (i) {
                      return GestureDetector(
                        onTap: () async {
                          if (await _showMoodSheet(context, i + 1) == true) _load();
                        },
                        child: Column(children: [
                          Container(
                            width: 54,
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Text(moodFaces[i], style: const TextStyle(fontSize: 30)),
                          ),
                          const SizedBox(height: 4),
                          Text(moodLabels[i], style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ]),
                      );
                    }),
                  ),
                  if (_moods.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MoodStrip(moods: _moods),
                  ],
                ]),
              ),
              if (_lowStretch) ...[
                const SizedBox(height: 12),
                WhiteCard(
                  color: const Color(0xFFFFF0F3),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('💗 You\'ve been feeling low lately', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text(
                      'Mood changes after having a baby are very common, and they are treatable. '
                      'If you have felt low or anxious for two weeks or more, please talk to your doctor or clinic, '
                      'and share how you feel with someone you trust. If you ever feel unsafe, go to the nearest hospital straight away.',
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              // Water
              if (d != null)
                WhiteCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Text('💧 Water', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Text('${d.water} / ${d.waterGoal} glasses',
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.sky)),
                    ]),
                    const SizedBox(height: 4),
                    Text('Breastfeeding mums need extra water. Tap a glass.',
                        style: t.bodySmall?.copyWith(color: AppColors.muted)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(d.waterGoal > d.water ? d.waterGoal : d.water + 1, (i) {
                        final full = i < d.water;
                        return GestureDetector(
                          onTap: () => _setWater(full && i == d.water - 1 ? i : i + 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 36,
                            height: 46,
                            decoration: BoxDecoration(
                              color: full ? AppColors.sky : AppColors.sky.withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12), top: Radius.circular(4)),
                              border: Border.all(color: AppColors.sky.withValues(alpha: 0.5)),
                            ),
                            alignment: Alignment.center,
                            child: full ? const Icon(Icons.water_drop, color: Colors.white, size: 18) : null,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      IconButton.filledTonal(
                          onPressed: d.water > 0 ? () => _setWater(d.water - 1) : null, icon: const Icon(Icons.remove)),
                      const SizedBox(width: 8),
                      IconButton.filled(onPressed: () => _setWater(d.water + 1), icon: const Icon(Icons.add)),
                    ]),
                  ]),
                ),
              const SizedBox(height: 12),
              // Sleep + breathing row
              if (d != null)
                Row(children: [
                  Expanded(
                    child: WhiteCard(
                      onTap: () async {
                        if (await _showSleepSheet(context, d) == true) _load();
                      },
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('😴', style: TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text('My sleep', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                        Text(
                          d.sleepHours == null ? 'Tap to log last night' : '${d.sleepHours} hrs · ${'★' * (d.sleepQuality ?? 0)}',
                          style: t.bodySmall?.copyWith(color: AppColors.muted),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WhiteCard(
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BreathingScreen()));
                        _load();
                      },
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('🌬️', style: TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text('Breathe', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                        Text(d.breathing == 0 ? '1-minute calm' : '${d.breathing} done today',
                            style: t.bodySmall?.copyWith(color: AppColors.muted)),
                      ]),
                    ),
                  ),
                ]),
              const SizedBox(height: 12),
              // Gratitude
              if (d != null) _GratitudeCard(day: d, history: _history, onAdded: (g, row) {
                setState(() => _day = row);
                _xp(g, 'Added to your journal');
              }),
              const SizedBox(height: 12),
              if (_history.length > 1) _WeekCard(history: _history),
            ]),
          ),
        ],
      ),
    );
  }
}

Future<bool?> _showMoodSheet(BuildContext context, int mood) {
  const tagOptions = ['Tired', 'Anxious', 'Overwhelmed', 'Lonely', 'Irritable', 'Calm', 'Happy', 'Grateful', 'Loved', 'Proud'];
  final picked = <String>{};
  final note = TextEditingController();
  var m = mood;
  var saving = false;
  return showAppSheet<bool>(context, 'Feeling ${moodLabels[mood - 1].toLowerCase()} ${moodFaces[mood - 1]}', (ctx, setS) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(5, (i) => GestureDetector(
              onTap: () => setS(() => m = i + 1),
              child: AnimatedScale(
                scale: m == i + 1 ? 1.25 : 0.9,
                duration: const Duration(milliseconds: 200),
                child: Text(moodFaces[i], style: TextStyle(fontSize: 34, color: m == i + 1 ? null : Colors.black38)),
              ),
            )),
      ),
      const SizedBox(height: 16),
      const Text('What\'s going on? (optional)', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tagOptions
            .map((tag) => FilterChip(
                  label: Text(tag),
                  selected: picked.contains(tag),
                  onSelected: (v) => setS(() => v ? picked.add(tag) : picked.remove(tag)),
                ))
            .toList(),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: note,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Write a little about it (private to you)'),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                setS(() => saving = true);
                try {
                  await WellnessService.logMood(m, picked.toList(), note.text);
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                    toast(ctx, 'Thanks for checking in 💗 +3 XP');
                  }
                } catch (_) {
                  setS(() => saving = false);
                  if (ctx.mounted) toast(ctx, 'Could not save. Please try again.');
                }
              },
        child: const Text('Save check-in'),
      ),
    ]);
  });
}

Future<bool?> _showSleepSheet(BuildContext context, WellnessDay d) {
  var hours = d.sleepHours ?? 6.0;
  var quality = d.sleepQuality ?? 3;
  var saving = false;
  return showAppSheet<bool>(context, 'How did you sleep?', (ctx, setS) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${hours.toStringAsFixed(1)} hours in total', textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      Slider(value: hours, min: 0, max: 12, divisions: 24, onChanged: (v) => setS(() => hours = v)),
      const SizedBox(height: 8),
      const Text('Sleep quality', style: TextStyle(fontWeight: FontWeight.w800)),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) => IconButton(
              iconSize: 36,
              onPressed: () => setS(() => quality = i + 1),
              icon: Icon(i < quality ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.sun),
            )),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                setS(() => saving = true);
                try {
                  final (g, _) = await WellnessService.logSleep(hours, quality);
                  if (ctx.mounted) {
                    Navigator.pop(ctx, true);
                    toast(ctx, g > 0 ? 'Sleep saved. +$g XP' : 'Sleep updated');
                  }
                } catch (_) {
                  setS(() => saving = false);
                }
              },
        child: const Text('Save'),
      ),
    ]);
  });
}

class _GratitudeCard extends StatefulWidget {
  final WellnessDay day;
  final List<WellnessDay> history;
  final void Function(int gained, WellnessDay row) onAdded;
  const _GratitudeCard({required this.day, required this.history, required this.onAdded});
  @override
  State<_GratitudeCard> createState() => _GratitudeCardState();
}

class _GratitudeCardState extends State<_GratitudeCard> {
  final _c = TextEditingController();
  bool _saving = false;

  Future<void> _add() async {
    if (_c.text.trim().length < 2) return;
    setState(() => _saving = true);
    try {
      final (g, row) = await WellnessService.addGratitude(_c.text);
      _c.clear();
      widget.onAdded(g, row);
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final past = widget.history.where((h) => !isSameDay(h.day, DateTime.now()) && h.gratitude.isNotEmpty).toList();
    return WhiteCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('🙏 Gratitude journal', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        Text('One small good thing, every day.', style: t.bodySmall?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 10),
        ...widget.day.gratitude.map((g) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('🌸 '),
                Expanded(child: Text(g, style: t.bodyLarge)),
              ]),
            )),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _c,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _add(),
              decoration: const InputDecoration(hintText: 'Today I\'m grateful for...'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _saving ? null : _add, icon: const Icon(Icons.send)),
        ]),
        if (past.isNotEmpty) ...[
          const SizedBox(height: 10),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Earlier this week', style: TextStyle(fontWeight: FontWeight.w800)),
              children: past
                  .map((h) => Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text('${shortDate(h.day)}: ${h.gratitude.join(' · ')}', style: t.bodyMedium),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ]),
    );
  }
}

class _MoodStrip extends StatelessWidget {
  final List<MoodLog> moods;
  const _MoodStrip({required this.moods});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day - 6 + i));
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((d) {
        final ms = moods.where((m) => isSameDay(m.at, d)).toList();
        final avg = ms.isEmpty ? null : (ms.map((m) => m.mood).reduce((a, b) => a + b) / ms.length).round();
        return Column(children: [
          Text(avg == null ? '·' : moodFaces[avg - 1], style: const TextStyle(fontSize: 20)),
          Text(names[d.weekday - 1], style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]);
      }).toList(),
    );
  }
}

class _WeekCard extends StatelessWidget {
  final List<WellnessDay> history;
  const _WeekCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final withSleep = history.where((h) => h.sleepHours != null).toList();
    final avgSleep = withSleep.isEmpty ? null : withSleep.map((h) => h.sleepHours!).reduce((a, b) => a + b) / withSleep.length;
    final goalDays = history.where((h) => h.water >= h.waterGoal).length;
    final breaths = history.fold<int>(0, (s, h) => s + h.breathing);
    return WhiteCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('This week', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _stat(context, avgSleep == null ? '–' : '${avgSleep.toStringAsFixed(1)}h', 'avg sleep'),
          _stat(context, '$goalDays/7', 'water goals'),
          _stat(context, '$breaths', 'breathing'),
        ]),
      ]),
    );
  }

  Widget _stat(BuildContext context, String v, String l) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Text(v, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      Text(l, style: t.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w700)),
    ]);
  }
}
