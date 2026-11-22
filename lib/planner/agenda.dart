import '../core/life_service.dart';
import '../core/time_utils.dart';
import '../meals/dishes.dart';
import '../meals/meals_service.dart';

/// One thing happening on a day, from any module.
class AgendaItem {
  final String emoji;
  final String title;
  final String? time;
  final String kind; // reminder, event, chore, household, school, bill, date, meal, class
  final bool done;
  AgendaItem(this.emoji, this.title, {this.time, required this.kind, this.done = false});
}

/// Collects everything between [from] and [to] (inclusive), keyed by yyyy-mm-dd.
Future<Map<String, List<AgendaItem>>> collectAgenda(DateTime from, DateTime to) async {
  final out = <String, List<AgendaItem>>{};
  void add(DateTime d, AgendaItem it) => (out[dateKey(d)] ??= []).add(it);
  final f = DateTime(from.year, from.month, from.day);
  final t = DateTime(to.year, to.month, to.day, 23, 59);
  bool inRange(DateTime d) => !d.isBefore(f) && !d.isAfter(t);

  Future<List<Rec>> safe(Future<List<Rec>> fut) async {
    try {
      return await fut;
    } catch (_) {
      return [];
    }
  }

  final r = await Future.wait([
    safe(Life.list('reminders', order: 'due_at')),
    safe(Life.list('family_events', order: 'starts_at')),
    safe(Life.list('chores', eq: {'done': false})),
    safe(Life.list('household_tasks')),
    safe(Life.list('kid_tasks', eq: {'done': false})),
    safe(Life.list('bills')),
    safe(Life.list('important_dates')),
    safe(Life.list('children', select: 'id,name,birth_date')),
    safe(Life.list('kid_schedule')),
  ]);
  final children = {for (final c in r[7]) '${c['id']}': '${c['name']}'};

  for (final x in r[0]) {
    final d = Life.parseDate(x['due_at']);
    if (d != null && inRange(d) && (x['done'] != true || x['repeat'] != 'none')) {
      add(d, AgendaItem(x['level'] == 'alarm' ? '⏰' : '🔔', '${x['title']}', time: clock(d), kind: 'reminder', done: x['done'] == true));
    }
  }
  for (final x in r[1]) {
    final d = Life.parseDate(x['starts_at']);
    if (d != null && inRange(d)) {
      add(d, AgendaItem('${x['emoji'] ?? '📅'}', '${x['title']}', time: x['all_day'] == true ? 'All day' : clock(d), kind: 'event'));
    }
  }
  for (final x in r[2]) {
    final d = Life.parseDate(x['due_date']);
    if (d != null && inRange(d)) add(d, AgendaItem('🧺', '${x['title']}', kind: 'chore'));
  }
  for (final x in r[3]) {
    final d = Life.parseDate(x['next_due']);
    if (d == null) continue;
    // show recurring household jobs on each of their days in the range
    var day = d;
    final step = switch ('${x['frequency']}') { 'daily' => 1, 'weekly' => 7, _ => 0 };
    var guard = 0;
    while (!day.isAfter(t) && guard++ < 62) {
      if (inRange(day)) add(day, AgendaItem('${x['emoji']}', '${x['title']}', kind: 'household'));
      if (step == 0) {
        if ('${x['frequency']}' != 'monthly') break;
        day = DateTime(day.year, day.month + 1, day.day);
      } else {
        day = day.add(Duration(days: step));
      }
    }
  }
  for (final x in r[4]) {
    final d = Life.parseDate(x['due_date']);
    if (d != null && inRange(d)) {
      final e = const {'homework': '📚', 'exam': '📝', 'school_event': '🏫', 'supplies': '🎒', 'medical': '🩺', 'activity': '⚽'}[x['category']] ?? '📌';
      add(d, AgendaItem(e, '${children[x['child_id']] ?? ''}: ${x['title']}', kind: 'school'));
    }
  }
  for (final x in r[5]) {
    final d = Life.parseDate(x['next_due']);
    if (d != null && inRange(d)) add(d, AgendaItem('${x['emoji']}', '${x['name']} due', kind: 'bill'));
  }
  // yearly dates
  for (var y = f.year; y <= t.year; y++) {
    for (final x in r[6]) {
      final d = DateTime(y, x['month'] as int, x['day'] as int);
      if (inRange(d)) {
        final yrs = x['year'] == null ? '' : ' (${y - (x['year'] as int)})';
        add(d, AgendaItem('${x['emoji']}', '${x['title']}$yrs', time: 'All day', kind: 'date'));
      }
    }
    for (final c in r[7]) {
      final b = DateTime.tryParse('${c['birth_date']}');
      if (b == null) continue;
      final d = DateTime(y, b.month, b.day);
      if (inRange(d) && y > b.year) add(d, AgendaItem('🎂', "${c['name']}'s birthday (${y - b.year})", time: 'All day', kind: 'date'));
    }
  }
  // weekly school timetable
  for (var d = f; !d.isAfter(t); d = d.add(const Duration(days: 1))) {
    for (final s in r[8].where((s) => s['weekday'] == d.weekday)) {
      add(d, AgendaItem('🏫', '${children[s['child_id']] ?? ''}: ${s['title']}', time: '${s['start_time']}', kind: 'class'));
    }
  }
  // meal plan (only for weeks that have a plan)
  try {
    for (var w = MealsService.weekStart(f); !w.isAfter(t); w = w.add(const Duration(days: 7))) {
      final plan = await MealsService.load(w);
      if (plan == null) continue;
      for (var i = 0; i < 7; i++) {
        final d = w.add(Duration(days: i));
        if (!inRange(d)) continue;
        final m = plan['$i'];
        final names = ['b', 'l', 'd'].map((s) => dishByKey(m?[s] ?? '')?.name).whereType<String>().toList();
        if (names.isNotEmpty) add(d, AgendaItem('🍲', names.join(' · '), kind: 'meal'));
      }
    }
  } catch (_) {}

  for (final list in out.values) {
    list.sort((a, b) {
      int rank(AgendaItem i) => i.time == null ? 2 : (i.time == 'All day' ? 0 : 1);
      final c = rank(a).compareTo(rank(b));
      if (c != 0) return c;
      return (a.time ?? '').compareTo(b.time ?? '');
    });
  }
  return out;
}
