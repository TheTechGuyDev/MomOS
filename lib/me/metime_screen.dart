import 'package:material_ui/material_ui.dart';

import '../core/life_service.dart';
import '../core/profile_service.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../widgets/form_sheet.dart';
import '../widgets/ui.dart';

const meCategories = <(String, String)>[
  ('self_care', '💆🏾‍♀️ Self-care'),
  ('exercise', '🏃🏾‍♀️ Exercise'),
  ('reading', '📖 Reading'),
  ('rest', '😌 Rest'),
  ('hobby', '🎨 Hobby'),
  ('prayer', '🙏 Prayer / quiet time'),
  ('learning', '🎓 Learning'),
];
String meEmoji(String c) => meCategories.firstWhere((x) => x.$1 == c, orElse: () => meCategories.first).$2.split(' ').first;

/// Personal routines, exercise, reading, hobbies and rest.
class MeTimeScreen extends StatefulWidget {
  const MeTimeScreen({super.key});
  @override
  State<MeTimeScreen> createState() => _MeTimeScreenState();
}

class _MeTimeScreenState extends State<MeTimeScreen> {
  List<Rec> _routines = [], _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = AppSession.uid;
      final since = Life.d(DateTime.now().subtract(const Duration(days: 6)));
      final r = await Future.wait([
        Life.list('routines', eq: {'user_id': uid, 'active': true}, order: 'time_of_day'),
        supa.from('activity_logs').select().eq('user_id', uid).gte('on_date', since).order('created_at', ascending: false),
      ]);
      if (mounted) {
        setState(() {
          _routines = r[0];
          _logs = (r[1] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editRoutine([Rec? r]) async {
    final v = await showFormSheet(context, title: r == null ? 'New routine' : 'Edit routine', fields: [
      FieldSpec('category', 'Type', FieldType.choice, options: meCategories),
      const FieldSpec('title', 'What?', FieldType.text, required: true, hint: 'e.g. 15-minute walk, read 10 pages'),
      const FieldSpec('time_of_day', 'Time (optional)', FieldType.text, hint: 'e.g. 6:30 AM'),
      const FieldSpec('minutes', 'Minutes', FieldType.number),
      const FieldSpec('days', 'Days', FieldType.multi, options: [('1', 'Mon'), ('2', 'Tue'), ('3', 'Wed'), ('4', 'Thu'), ('5', 'Fri'), ('6', 'Sat'), ('7', 'Sun')]),
    ], initial: {
      'category': r?['category'] ?? 'self_care',
      'title': r?['title'],
      'time_of_day': r?['time_of_day'],
      'minutes': r?['minutes'],
      'days': ((r?['days'] as List?) ?? [1, 2, 3, 4, 5, 6, 7]).map((e) => '$e').toList(),
    });
    if (v == null) return;
    final data = {
      'category': v['category'],
      'emoji': meEmoji('${v['category']}'),
      'title': v['title'],
      'time_of_day': v['time_of_day'],
      'minutes': v['minutes'],
      'days': ((v['days'] as List?) ?? []).map((e) => int.parse('$e')).toList(),
    };
    r == null ? await Life.insert('routines', data, family: false) : await Life.update('routines', '${r['id']}', data);
    _load();
  }

  Future<void> _log({Rec? routine}) async {
    Map<String, dynamic>? v;
    if (routine == null) {
      v = await showFormSheet(context, title: 'Log me-time', fields: [
        FieldSpec('category', 'Type', FieldType.choice, options: meCategories),
        const FieldSpec('name', 'What did you do?', FieldType.text, required: true, hint: 'e.g. Evening walk'),
        const FieldSpec('minutes', 'Minutes', FieldType.number),
        const FieldSpec('note', 'Note (optional)', FieldType.text),
      ], initial: {'category': 'exercise'});
      if (v == null) return;
    }
    await Life.insert('activity_logs', {
      'routine_id': routine?['id'],
      'category': routine?['category'] ?? v!['category'],
      'name': routine?['title'] ?? v!['name'],
      'minutes': routine?['minutes'] ?? v!['minutes'],
      'note': v?['note'],
    }, family: false, xp: true);
    if (mounted) toast(context, 'Well done for making time for you 💗 +3 XP');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final today = dateKey(DateTime.now());
    final wd = DateTime.now().weekday;
    final todays = _routines.where((r) => List<int>.from((r['days'] ?? []) as List).contains(wd)).toList();
    final doneIds = _logs.where((l) => l['on_date'] == today).map((l) => l['routine_id']).toSet();
    final minutes = <String, int>{};
    for (final l in _logs) {
      minutes['${l['category']}'] = (minutes['${l['category']}'] ?? 0) + ((l['minutes'] as int?) ?? 0);
    }
    final totalWeek = minutes.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: const Text('Me time 🧘🏾‍♀️')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _log(), icon: const Icon(Icons.add), label: const Text('Log time')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.secondary, AppColors.primary]),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Time for you this week', style: TextStyle(color: Colors.white70)),
                    Text(durationText(Duration(minutes: totalWeek)), style: t.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 10, children: minutes.entries
                        .map((e) => Text('${meEmoji(e.key)} ${e.value}m', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)))
                        .toList()),
                    if (totalWeek < 60)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Even 10 minutes a day for yourself makes a difference 💗', style: TextStyle(color: Colors.white)),
                      ),
                  ]),
                ),
                SectionTitle('Today\'s routine', trailing: TextButton.icon(onPressed: () => _editRoutine(), icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
                if (todays.isEmpty)
                  const Text('Add a small daily routine: a walk, a skincare moment, 10 pages of a book, or quiet prayer time.',
                      style: TextStyle(color: AppColors.muted)),
                ...todays.map((r) {
                  final done = doneIds.contains(r['id']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: WhiteCard(
                      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                      onTap: () => _editRoutine(r),
                      child: Row(children: [
                        Text('${r['emoji']}', style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${r['title']}', style: TextStyle(fontWeight: FontWeight.w800, decoration: done ? TextDecoration.lineThrough : null)),
                            Text([if (r['time_of_day'] != null) '${r['time_of_day']}', if (r['minutes'] != null) '${r['minutes']} min'].join(' · '),
                                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ]),
                        ),
                        done
                            ? const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.check_circle, color: AppColors.mint))
                            : FilledButton.tonal(onPressed: () => _log(routine: r), child: const Text('Done')),
                      ]),
                    ),
                  );
                }),
                const SectionTitle('This week'),
                if (_logs.isEmpty) const Text('Nothing logged yet.', style: TextStyle(color: AppColors.muted)),
                ..._logs.take(20).map((l) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(meEmoji('${l['category']}'), style: const TextStyle(fontSize: 22)),
                      title: Text('${l['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${shortDate(DateTime.parse('${l['on_date']}'))}${l['minutes'] != null ? ' · ${l['minutes']} min' : ''}'),
                    )),
              ]),
            ),
    );
  }
}
