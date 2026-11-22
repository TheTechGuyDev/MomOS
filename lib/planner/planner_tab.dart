import 'package:material_ui/material_ui.dart';

import '../core/life_service.dart';
import '../core/profile_service.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../screens/family/family_screen.dart';
import '../screens/memory/notes_view.dart';
import '../screens/memory/places_view.dart';
import '../screens/memory/reminders_view.dart';
import '../widgets/form_sheet.dart';
import '../widgets/ui.dart';
import 'agenda.dart';

class PlannerTab extends StatefulWidget {
  const PlannerTab({super.key});
  @override
  State<PlannerTab> createState() => _PlannerTabState();
}

class _PlannerTabState extends State<PlannerTab> {
  String _view = 'calendar';
  final _cal = GlobalKey<_CalendarState>();
  final _rem = GlobalKey<RemindersViewState>();
  final _goals = GlobalKey<_GoalsState>();
  final _dates = GlobalKey<_DatesState>();

  Future<void> _add() async {
    final what = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Text('🔔', style: TextStyle(fontSize: 22)), title: const Text('Reminder or task'), onTap: () => Navigator.pop(ctx, 'reminder')),
          ListTile(leading: const Text('📅', style: TextStyle(fontSize: 22)), title: const Text('Appointment or family event'), onTap: () => Navigator.pop(ctx, 'event')),
          ListTile(leading: const Text('🎯', style: TextStyle(fontSize: 22)), title: const Text('Personal goal'), onTap: () => Navigator.pop(ctx, 'goal')),
          ListTile(leading: const Text('🎂', style: TextStyle(fontSize: 22)), title: const Text('Birthday or important date'), onTap: () => Navigator.pop(ctx, 'date')),
        ]),
      ),
    );
    if (!mounted || what == null) return;
    bool? ok;
    switch (what) {
      case 'reminder':
        ok = await showReminderSheet(context);
      case 'event':
        ok = await showEventSheet(context, day: _cal.currentState?._selected);
      case 'goal':
        ok = await editGoal(context);
      case 'date':
        ok = await editDate(context);
    }
    if (ok == true) {
      _cal.currentState?.load();
      _rem.currentState?.load();
      _goals.currentState?.load();
      _dates.currentState?.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: Column(children: [
        const TabHeader(title: 'Planner', subtitle: 'Your days, reminders, goals and dates'),
        SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            children: [
              for (final (k, l) in const [('calendar', '📅 Calendar'), ('reminders', '🔔 Reminders'), ('goals', '🎯 Goals'), ('dates', '🎂 Dates'), ('notes', '📝 Notes'), ('places', '🔎 Where is it?')])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text(l), selected: _view == k, onSelected: (_) => setState(() => _view = k)),
                ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: ['calendar', 'reminders', 'goals', 'dates', 'notes', 'places'].indexOf(_view),
            children: [
              _Calendar(key: _cal),
              RemindersView(key: _rem),
              _Goals(key: _goals),
              _Dates(key: _dates),
              const NotesView(),
              const PlacesView(),
            ],
          ),
        ),
      ]),
    );
  }
}

// ---------------- Calendar: month / week / day ----------------

class _Calendar extends StatefulWidget {
  const _Calendar({super.key});
  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
  String _mode = 'month';
  DateTime _selected = DateTime.now();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, List<AgendaItem>> _agenda = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() => _loading = true);
    final from = DateTime(_month.year, _month.month, 1).subtract(const Duration(days: 7));
    final to = DateTime(_month.year, _month.month + 1, 7);
    final a = await collectAgenda(from, to);
    if (mounted) {
      setState(() {
        _agenda = a;
        _loading = false;
      });
    }
  }

  void _shiftMonth(int by) {
    _month = DateTime(_month.year, _month.month + by);
    _selected = DateTime(_month.year, _month.month, by > 0 ? 1 : DateTime(_month.year, _month.month + 1, 0).day);
    load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        Row(children: [
          ChipChoices<String>(
            options: const [('month', 'Month'), ('week', 'Week'), ('day', 'Day')],
            value: _mode,
            onChanged: (v) => setState(() => _mode = v),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              final n = DateTime.now();
              setState(() {
                _selected = n;
                if (_month.month != n.month || _month.year != n.year) {
                  _month = DateTime(n.year, n.month);
                  load();
                }
              });
            },
            child: const Text('Today'),
          ),
        ]),
        if (_mode == 'month') ...[
          Row(children: [
            IconButton(onPressed: () => _shiftMonth(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(child: Text('${months[_month.month - 1]} ${_month.year}', textAlign: TextAlign.center, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            IconButton(onPressed: () => _shiftMonth(1), icon: const Icon(Icons.chevron_right)),
          ]),
          _monthGrid(),
          const SizedBox(height: 8),
          _dayAgenda(_selected),
        ] else if (_mode == 'week') ...[
          _weekView(),
        ] else ...[
          Row(children: [
            IconButton(onPressed: () => _moveDay(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(child: Text(isSameDay(_selected, DateTime.now()) ? 'Today' : shortDate(_selected), textAlign: TextAlign.center, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
            IconButton(onPressed: () => _moveDay(1), icon: const Icon(Icons.chevron_right)),
          ]),
          _dayAgenda(_selected, big: true),
        ],
        if (_loading) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator(minHeight: 3)),
      ]),
    );
  }

  void _moveDay(int by) {
    final n = _selected.add(Duration(days: by));
    setState(() => _selected = n);
    if (n.month != _month.month) {
      _month = DateTime(n.year, n.month);
      load();
    }
  }

  Widget _monthGrid() {
    final first = DateTime(_month.year, _month.month, 1);
    final start = first.subtract(Duration(days: first.weekday - 1));
    const wd = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(children: wd.map((w) => Expanded(child: Center(child: Text(w, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w800))))).toList()),
        const SizedBox(height: 4),
        for (var row = 0; row < 6; row++)
          Row(children: [
            for (var c = 0; c < 7; c++)
              Builder(builder: (context) {
                final d = start.add(Duration(days: row * 7 + c));
                final inMonth = d.month == _month.month;
                final sel = isSameDay(d, _selected);
                final today = isSameDay(d, DateTime.now());
                final items = _agenda[dateKey(d)] ?? const [];
                final kinds = items.map((i) => i.kind).toSet();
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selected = d),
                    child: Container(
                      height: 46,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : (today ? AppColors.primary.withValues(alpha: 0.12) : null),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${d.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: sel ? Colors.white : (inMonth ? AppColors.ink : AppColors.muted.withValues(alpha: 0.5)),
                            )),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (final k in kinds.where((k) => k != 'meal' && k != 'class').take(3))
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: sel ? Colors.white : _kindColor(k)),
                            ),
                        ]),
                      ]),
                    ),
                  ),
                );
              }),
          ]),
      ]),
    );
  }

  Color _kindColor(String k) => switch (k) {
        'reminder' => AppColors.primary,
        'event' => AppColors.secondary,
        'bill' => Colors.orange,
        'date' => AppColors.sun,
        'school' => AppColors.sky,
        _ => AppColors.mint,
      };

  Widget _weekView() {
    final start = _selected.subtract(Duration(days: _selected.weekday - 1));
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Column(children: [
      Row(children: [
        IconButton(
          onPressed: () {
            setState(() => _selected = _selected.subtract(const Duration(days: 7)));
            if (_selected.month != _month.month) {
              _month = DateTime(_selected.year, _selected.month);
              load();
            }
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(child: Text('Week of ${shortDate(start)}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900))),
        IconButton(
          onPressed: () {
            setState(() => _selected = _selected.add(const Duration(days: 7)));
            if (_selected.month != _month.month) {
              _month = DateTime(_selected.year, _selected.month);
              load();
            }
          },
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
      for (var i = 0; i < 7; i++)
        Builder(builder: (context) {
          final d = start.add(Duration(days: i));
          final items = (_agenda[dateKey(d)] ?? const <AgendaItem>[]).where((x) => x.kind != 'class').toList();
          final today = isSameDay(d, DateTime.now());
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: WhiteCard(
              color: today ? AppColors.primary.withValues(alpha: 0.06) : null,
              onTap: () => setState(() {
                _selected = d;
                _mode = 'day';
              }),
              padding: const EdgeInsets.all(12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 44,
                  child: Column(children: [
                    Text(names[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: today ? AppColors.primary : AppColors.muted)),
                    Text('${d.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: today ? AppColors.primary : AppColors.ink)),
                  ]),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: items.isEmpty
                      ? const Text('Free day', style: TextStyle(color: AppColors.muted))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: items.take(4).map((x) => Text('${x.emoji} ${x.time != null && x.time != 'All day' ? '${x.time} ' : ''}${x.title}',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))).toList()
                            ..addAll([if (items.length > 4) Text('+${items.length - 4} more', style: const TextStyle(fontSize: 12, color: AppColors.muted))]),
                        ),
                ),
              ]),
            ),
          );
        }),
    ]);
  }

  Widget _dayAgenda(DateTime d, {bool big = false}) {
    final items = _agenda[dateKey(d)] ?? const <AgendaItem>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!big) SectionTitle(isSameDay(d, DateTime.now()) ? 'Today' : shortDate(d)),
      if (items.isEmpty)
        const Padding(padding: EdgeInsets.all(16), child: Text('Nothing planned. Tap + to add something.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted))),
      ...items.map((x) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: WhiteCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                Text(x.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(child: Text(x.title, style: TextStyle(fontWeight: FontWeight.w700, decoration: x.done ? TextDecoration.lineThrough : null))),
                if (x.time != null) Text(x.time!, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
              ]),
            ),
          )),
    ]);
  }
}

// ---------------- Goals ----------------

Future<bool?> editGoal(BuildContext context, [Rec? g]) async {
  final v = await showFormSheet(context, title: g == null ? 'New personal goal' : 'Edit goal', fields: [
    const FieldSpec('emoji', 'Icon', FieldType.emoji),
    const FieldSpec('title', 'Goal', FieldType.text, required: true, hint: 'e.g. Walk 20 minutes, finish SQL track, save ₦50k'),
    const FieldSpec('category', 'Area', FieldType.choice, options: [
      ('personal', 'Personal'), ('health', 'Health'), ('learning', 'Learning'), ('career', 'Career'), ('money', 'Money'), ('home', 'Home'), ('family', 'Family'),
    ]),
    const FieldSpec('period', 'Type', FieldType.choice, options: [('daily', 'Daily habit'), ('weekly', 'Weekly'), ('once', 'One-time goal')]),
    const FieldSpec('target', 'Target number (optional)', FieldType.number, hint: 'e.g. 23 lessons, 12 books'),
    const FieldSpec('unit', 'Unit (optional)', FieldType.text, hint: 'e.g. lessons, books, kg'),
    const FieldSpec('due_date', 'By when? (optional)', FieldType.date),
    const FieldSpec('shared', 'Share with family', FieldType.toggle, hint: 'Off = private to you'),
  ], initial: {
    'emoji': g?['emoji'] ?? '🎯',
    'title': g?['title'],
    'category': g?['category'] ?? 'personal',
    'period': g?['period'] ?? 'daily',
    'target': g?['target'],
    'unit': g?['unit'],
    'due_date': Life.parseDate(g?['due_date']),
    'shared': g?['shared'] ?? false,
  }, emojis: const ['🎯', '💪', '📚', '🎓', '💰', '🏃🏾‍♀️', '🧘🏾‍♀️', '💧', '🙏', '✍️', '🏠', '💼']);
  if (v == null) return null;
  final data = {
    'emoji': v['emoji'],
    'title': v['title'],
    'category': v['category'],
    'period': v['period'],
    'target': v['target'],
    'unit': v['unit'],
    'due_date': v['due_date'] == null ? null : Life.d(v['due_date'] as DateTime),
    'shared': v['shared'] ?? false,
  };
  g == null ? await Life.insert('goals', data) : await Life.update('goals', '${g['id']}', data);
  return true;
}

class _Goals extends StatefulWidget {
  const _Goals({super.key});
  @override
  State<_Goals> createState() => _GoalsState();
}

class _GoalsState extends State<_Goals> {
  List<Rec> _goals = [];
  Map<String, int> _streak = {};
  Set<String> _today = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final g = await Life.list('goals', eq: {'user_id': AppSession.uid}, order: 'created_at');
      final since = Life.d(DateTime.now().subtract(const Duration(days: 30)));
      final ch = await supa.from('goal_checkins').select().gte('day', since);
      final byGoal = <String, Set<String>>{};
      for (final c in ch) {
        (byGoal['${c['goal_id']}'] ??= {}).add('${c['day']}');
      }
      final streak = <String, int>{};
      final todayKey = dateKey(DateTime.now());
      byGoal.forEach((id, days) {
        var d = DateTime.now();
        if (!days.contains(dateKey(d))) d = d.subtract(const Duration(days: 1));
        var n = 0;
        while (days.contains(dateKey(d))) {
          n++;
          d = d.subtract(const Duration(days: 1));
        }
        streak[id] = n;
      });
      if (mounted) {
        setState(() {
          _goals = g;
          _streak = streak;
          _today = byGoal.entries.where((e) => e.value.contains(todayKey)).map((e) => e.key).toSet();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _progress(Rec g) async {
    num add = 1;
    if (g['period'] != 'daily' && g['target'] != null) {
      final v = await showFormSheet(context, title: 'Add progress', fields: [
        FieldSpec('add', 'How much? (${g['unit'] ?? 'steps'})', FieldType.number, required: true),
      ], initial: {'add': 1});
      if (v == null) return;
      add = v['add'] as num;
    }
    try {
      await Life.rpc('goal_progress', {'p_id': g['id'], 'p_add': add});
      if (mounted) toast(context, 'Nice progress! +5 XP');
    } catch (_) {}
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final open = _goals.where((g) => g['done'] != true).toList();
    final done = _goals.where((g) => g['done'] == true).toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
        if (_goals.isEmpty)
          EmptyState(
            emoji: '🎯',
            title: 'Set goals that are just for you',
            subtitle: 'Daily habits like "walk 20 minutes", or bigger dreams like "finish the Data Analysis course".',
            action: FilledButton(
              onPressed: () async {
                if (await editGoal(context) == true) load();
              },
              child: const Text('Add a goal'),
            ),
          ),
        ...open.map((g) {
          final daily = g['period'] == 'daily';
          final checked = _today.contains('${g['id']}');
          final target = g['target'] as num?;
          final pct = target == null || target == 0 ? null : ((g['progress'] as num) / target).clamp(0, 1).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: WhiteCard(
              onTap: () async {
                if (await editGoal(context, g) == true) load();
              },
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('${g['emoji']}', style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${g['title']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(
                        [
                          daily ? 'Daily · 🔥 ${_streak['${g['id']}'] ?? 0} day streak' : (g['period'] == 'weekly' ? 'Weekly' : 'Goal'),
                          if (target != null) '${g['progress']}/$target ${g['unit'] ?? ''}',
                          if (g['due_date'] != null) 'by ${shortDate(DateTime.parse('${g['due_date']}'))}',
                          if (g['shared'] == true) 'shared',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ]),
                  ),
                  daily
                      ? IconButton(
                          iconSize: 32,
                          onPressed: checked ? null : () => _progress(g),
                          icon: Icon(checked ? Icons.check_circle : Icons.radio_button_unchecked, color: checked ? AppColors.mint : AppColors.muted),
                        )
                      : FilledButton.tonal(onPressed: () => _progress(g), child: Text(target == null ? 'Done' : '+ Progress')),
                ]),
                if (pct != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: pct, minHeight: 8)),
                ],
              ]),
            ),
          );
        }),
        if (done.isNotEmpty) ...[
          const SectionTitle('Achieved 🎉'),
          ...done.map((g) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text('${g['emoji']}', style: const TextStyle(fontSize: 22)),
                title: Text('${g['title']}', style: const TextStyle(decoration: TextDecoration.lineThrough)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                  onPressed: () async {
                    await Life.delete('goals', '${g['id']}');
                    load();
                  },
                ),
              )),
        ],
      ]),
    );
  }
}

// ---------------- Important dates ----------------

Future<bool?> editDate(BuildContext context, [Rec? d]) async {
  final v = await showFormSheet(context, title: d == null ? 'Important date' : 'Edit date', fields: [
    const FieldSpec('emoji', 'Icon', FieldType.emoji),
    const FieldSpec('title', 'What is it?', FieldType.text, required: true, hint: "e.g. Mum's birthday, wedding anniversary"),
    const FieldSpec('kind', 'Type', FieldType.choice, options: [('birthday', 'Birthday'), ('anniversary', 'Anniversary'), ('school', 'School'), ('religious', 'Religious'), ('other', 'Other')]),
    const FieldSpec('date', 'Date', FieldType.date, required: true),
    const FieldSpec('has_year', 'Count the years (age / anniversary)', FieldType.toggle),
    const FieldSpec('remind_days_before', 'Remind me how many days before?', FieldType.number),
    const FieldSpec('shared', 'Share with family', FieldType.toggle),
  ], initial: {
    'emoji': d?['emoji'] ?? '🎂',
    'title': d?['title'],
    'kind': d?['kind'] ?? 'birthday',
    'date': d == null ? null : DateTime(d['year'] as int? ?? DateTime.now().year, d['month'] as int, d['day'] as int),
    'has_year': d?['year'] != null,
    'remind_days_before': d?['remind_days_before'] ?? 1,
    'shared': d?['shared'] ?? true,
  }, emojis: const ['🎂', '💍', '🎉', '🏫', '⛪', '🕌', '🎄', '🌙', '👶', '💐', '🎓', '⭐']);
  if (v == null) return null;
  final dt = v['date'] as DateTime;
  final data = {
    'emoji': v['emoji'],
    'title': v['title'],
    'kind': v['kind'],
    'month': dt.month,
    'day': dt.day,
    'year': v['has_year'] == true ? dt.year : null,
    'remind_days_before': (v['remind_days_before'] as num?)?.toInt() ?? 1,
    'shared': v['shared'] ?? true,
  };
  d == null ? await Life.insert('important_dates', data) : await Life.update('important_dates', '${d['id']}', data);
  return true;
}

class _Dates extends StatefulWidget {
  const _Dates({super.key});
  @override
  State<_Dates> createState() => _DatesState();
}

class _DatesState extends State<_Dates> {
  List<(DateTime, Rec?, String, String)> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await Future.wait([Life.list('important_dates'), Life.list('children', select: 'id,name,birth_date')]);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime next(int m, int d) {
        final x = DateTime(now.year, m, d);
        return x.isBefore(today) ? DateTime(now.year + 1, m, d) : x;
      }

      final items = <(DateTime, Rec?, String, String)>[];
      for (final d in r[0]) {
        final n = next(d['month'] as int, d['day'] as int);
        final yrs = d['year'] == null ? '' : ' · ${n.year - (d['year'] as int)} years';
        items.add((n, d, '${d['emoji']} ${d['title']}', '${d['kind']}$yrs'));
      }
      for (final c in r[1]) {
        final b = DateTime.tryParse('${c['birth_date']}');
        if (b == null) continue;
        final n = next(b.month, b.day);
        items.add((n, null, "🎂 ${c['name']}'s birthday", 'turns ${n.year - b.year}'));
      }
      items.sort((a, b) => a.$1.compareTo(b.$1));
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
        if (_items.isEmpty)
          const EmptyState(emoji: '🎂', title: 'Never forget a special day', subtitle: 'Add birthdays, anniversaries and other dates. Children\'s birthdays appear here automatically.'),
        ..._items.map((it) {
          final days = it.$1.difference(today).inDays;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: WhiteCard(
              onTap: it.$2 == null
                  ? null
                  : () async {
                      if (await editDate(context, it.$2) == true) load();
                    },
              child: Row(children: [
                Container(
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(color: AppColors.sun.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Text(days == 0 ? 'TODAY' : '$days', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    if (days != 0) const Text('days', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.$3, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${shortDate(it.$1)} · ${it.$4}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}
