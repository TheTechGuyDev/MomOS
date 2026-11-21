import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../core/kids_service.dart';
import '../../core/theme.dart';
import '../../core/time_utils.dart';
import 'log_sheets.dart';

class TodayView extends StatefulWidget {
  final Child child;
  const TodayView({super.key, required this.child});
  @override
  State<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends State<TodayView> {
  DateTime _day = DateTime.now();
  List<KidLog> _logs = [];
  KidLog? _lastFeed, _activeSleep, _lastSleep, _lastMedicine;
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(TodayView old) {
    super.didUpdateWidget(old);
    if (old.child.id != widget.child.id) _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final c = widget.child.id;
    final start = DateTime(_day.year, _day.month, _day.day);
    final end = start.add(const Duration(days: 1));
    try {
      final r = await Future.wait([
        KidsService.logs(c, since: start),
        KidsService.latest(c, 'feed'),
        KidsService.latest(c, 'sleep'),
        KidsService.latestMedicine(c),
      ]);
      if (!mounted) return;
      final dayLogs = (r[0] as List<KidLog>).where((l) => l.startedAt.isBefore(end)).toList();
      final sleep = r[2] as KidLog?;
      setState(() {
        _logs = dayLogs;
        _lastFeed = r[1] as KidLog?;
        _activeSleep = sleep != null && sleep.endedAt == null ? sleep : null;
        _lastSleep = sleep;
        _lastMedicine = r[3] as KidLog?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _after(Future<bool?> f) async {
    final saved = await f;
    if (saved == true) {
      await _load();
      if (mounted) _toast('Saved');
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 1)));

  Future<void> _toggleSleep() async {
    try {
      if (_activeSleep != null) {
        await KidsService.endSleep(_activeSleep!.id);
        _toast('${widget.child.name} is awake. Sleep saved.');
      } else {
        await KidsService.addLog(widget.child.id, 'sleep');
        _toast('Sleep timer started');
      }
      await _load();
    } catch (_) {
      _toast('Could not save. Please try again.');
    }
  }

  Future<void> _delete(KidLog l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(l.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await KidsService.deleteLog(l.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final c = widget.child;
    final isToday = isSameDay(_day, DateTime.now());
    final little = c.isBaby;
    final feedsToday = _logs.where((l) => l.kind == 'feed').length;
    final diapersToday = _logs.where((l) => l.kind == 'diaper').length;
    final healthToday = _logs.where((l) => l.kind == 'health').length;
    final sleepToday = _logs
        .where((l) => l.kind == 'sleep')
        .fold<Duration>(Duration.zero, (sum, l) => sum + ((l.endedAt ?? DateTime.now()).difference(l.startedAt)));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_activeSleep != null)
            _SleepBanner(name: c.name, since: _activeSleep!.startedAt, onWake: _toggleSleep),
          Row(
            children: [
              Expanded(
                child: _Summary(
                  emoji: little ? '🍼' : '🍽️',
                  title: little ? 'Last feed' : 'Last meal',
                  value: _lastFeed == null ? 'None yet' : timeAgo(_lastFeed!.startedAt),
                  sub: _lastFeed?.title,
                  color: AppColors.sky,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Summary(
                  emoji: '😴',
                  title: _activeSleep != null ? 'Asleep for' : 'Awake for',
                  value: _activeSleep != null
                      ? durationText(DateTime.now().difference(_activeSleep!.startedAt))
                      : (_lastSleep?.endedAt == null ? 'No sleep logged' : durationText(DateTime.now().difference(_lastSleep!.endedAt!))),
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_lastMedicine != null)
            _Summary(
              emoji: '💊',
              title: 'Last medicine',
              value: '${_lastMedicine!.data['medicine']}',
              sub: '${timeAgo(_lastMedicine!.startedAt)} (${clock(_lastMedicine!.startedAt)})',
              color: AppColors.primary,
            ),
          const SizedBox(height: 18),
          Text('Quick log', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: little
                ? [
                    _Action('🤱', 'Feed', AppColors.sky, () => _after(showFeedSheet(context, c))),
                    _Action(_activeSleep != null ? '🌞' : '😴', _activeSleep != null ? 'Wake up' : 'Sleep',
                        AppColors.secondary, _toggleSleep),
                    _Action('🧷', 'Diaper', AppColors.mint, () => _after(showDiaperSheet(context, c))),
                    _Action('📏', 'Growth', AppColors.sun, () => _after(showGrowthSheet(context, c))),
                    _Action('🌡️', 'Health', AppColors.primary, () => _after(showHealthSheet(context, c))),
                    _Action('🕰️', 'Past sleep', AppColors.secondary, () => _after(showSleepSheet(context, c))),
                  ]
                : [
                    _Action('🍽️', 'Meal', AppColors.sky, () => _after(showMealSheet(context, c))),
                    _Action(_activeSleep != null ? '🌞' : '🌙', _activeSleep != null ? 'Woke up' : 'Bedtime',
                        AppColors.secondary, _toggleSleep),
                    _Action('🌡️', 'Health', AppColors.primary, () => _after(showHealthSheet(context, c))),
                    _Action('📏', 'Growth', AppColors.sun, () => _after(showGrowthSheet(context, c))),
                    _Action('🕰️', 'Past sleep', AppColors.mint, () => _after(showSleepSheet(context, c))),
                  ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() => _day = _day.subtract(const Duration(days: 1)));
                  _load();
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  isToday ? 'Today' : shortDate(_day),
                  textAlign: TextAlign.center,
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                onPressed: isToday
                    ? null
                    : () {
                        setState(() => _day = _day.add(const Duration(days: 1)));
                        _load();
                      },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Count('$feedsToday', little ? 'feeds' : 'meals'),
                _Count(durationText(sleepToday), 'sleep'),
                little ? _Count('$diapersToday', 'diapers') : _Count('$healthToday', 'health notes'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_logs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Nothing logged ${isToday ? 'yet today' : 'on this day'}.',
                  textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
            ),
          ..._logs.map((l) => Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: Text(l.emoji, style: const TextStyle(fontSize: 26)),
                  title: Text(l.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    l.kind == 'sleep' && l.endedAt != null
                        ? '${clock(l.startedAt)} to ${clock(l.endedAt!)}'
                        : clock(l.startedAt),
                    if (l.note != null) l.note!,
                  ].join(' · ')),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                    onPressed: () => _delete(l),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _SleepBanner extends StatelessWidget {
  final String name;
  final DateTime since;
  final VoidCallback onWake;
  const _SleepBanner({required this.name, required this.since, required this.onWake});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3B3563), AppColors.secondary]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const Text('🌙', style: TextStyle(fontSize: 34)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name is sleeping',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                Text('Since ${clock(since)} · ${durationText(DateTime.now().difference(since))}',
                    style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(80, 42),
            ),
            onPressed: onWake,
            child: const Text('Woke up'),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final String emoji, title, value;
  final String? sub;
  final Color color;
  const _Summary({required this.emoji, required this.title, required this.value, this.sub, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w700)),
                Text(value, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                if (sub != null)
                  Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String emoji, label;
  final Color color;
  final VoidCallback onTap;
  const _Action(this.emoji, this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String value, label;
  const _Count(this.value, this.label);
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      Text(label, style: t.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w700)),
    ]);
  }
}
