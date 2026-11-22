import 'package:material_ui/material_ui.dart';

import '../core/kids_service.dart';
import '../core/life_service.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../widgets/form_sheet.dart';
import '../widgets/ui.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// School life per child: timetable, exams & assignments, fees, supplies checklist, medical appointments.
class SchoolView extends StatefulWidget {
  const SchoolView({super.key});
  @override
  State<SchoolView> createState() => _SchoolViewState();
}

class _SchoolViewState extends State<SchoolView> {
  List<Child> _children = [];
  String? _childId;
  List<Rec> _schedule = [], _tasks = [], _fees = [], _appts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Child? get _child => _children.where((c) => c.id == _childId).firstOrNull;

  Future<void> _load() async {
    try {
      final kids = await KidsService.children();
      _childId ??= kids.where((k) => !k.isBaby).firstOrNull?.id ?? kids.firstOrNull?.id;
      if (_childId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final r = await Future.wait([
        Life.list('kid_schedule', eq: {'child_id': _childId}, order: 'start_time'),
        Life.list('kid_tasks', eq: {'child_id': _childId}, order: 'due_date'),
        Life.list('bills', eq: {'child_id': _childId}, order: 'next_due'),
        Life.list('family_events', eq: {'child_id': _childId}, order: 'starts_at'),
      ]);
      if (mounted) {
        setState(() {
          _children = kids;
          _schedule = r[0];
          _tasks = r[1];
          _fees = r[2];
          _appts = r[3].where((e) => DateTime.parse('${e['starts_at']}').isAfter(DateTime.now().subtract(const Duration(days: 1)))).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addClass() async {
    final v = await showFormSheet(context, title: 'Add to timetable', fields: [
      const FieldSpec('weekday', 'Day', FieldType.choice, options: [('1', 'Mon'), ('2', 'Tue'), ('3', 'Wed'), ('4', 'Thu'), ('5', 'Fri'), ('6', 'Sat'), ('7', 'Sun')]),
      const FieldSpec('title', 'Subject or activity', FieldType.text, required: true, hint: 'e.g. School, Maths lesson, Swimming, Pick-up'),
      const FieldSpec('start_time', 'Start time', FieldType.text, required: true, hint: 'e.g. 7:30 AM'),
      const FieldSpec('end_time', 'End time (optional)', FieldType.text, hint: 'e.g. 1:30 PM'),
      const FieldSpec('kind', 'Type', FieldType.choice, options: [('class', 'Class'), ('activity', 'Activity'), ('pickup', 'Drop-off / pick-up'), ('other', 'Other')]),
      const FieldSpec('all_week', 'Repeat Monday to Friday', FieldType.toggle),
    ], initial: {'weekday': '${DateTime.now().weekday.clamp(1, 5)}', 'kind': 'class'});
    if (v == null) return;
    final days = v['all_week'] == true ? [1, 2, 3, 4, 5] : [int.parse('${v['weekday']}')];
    for (final d in days) {
      await Life.insert('kid_schedule', {
        'child_id': _childId,
        'weekday': d,
        'title': v['title'],
        'start_time': v['start_time'],
        'end_time': v['end_time'],
        'kind': v['kind'],
      });
    }
    _load();
  }

  Future<void> _addTask(String category) async {
    final labels = {'exam': 'Exam or test', 'homework': 'Assignment', 'supplies': 'School supply', 'school_event': 'School event'};
    final v = await showFormSheet(context, title: 'Add ${labels[category]!.toLowerCase()}', fields: [
      FieldSpec('title', labels[category]!, FieldType.text, required: true,
          hint: category == 'supplies' ? 'e.g. 2 HB pencils, crayons, lunch box' : 'e.g. Maths test, science project'),
      if (category != 'supplies') const FieldSpec('due_date', 'Date', FieldType.date, required: true),
    ], initial: {'due_date': DateTime.now().add(const Duration(days: 3))});
    if (v == null) return;
    await KidsService.addTask(_childId!, v['title'] as String, category, v['due_date'] as DateTime?);
    _load();
  }

  Future<void> _addFee() async {
    final v = await showFormSheet(context, title: 'School fees', fields: [
      const FieldSpec('name', 'What for?', FieldType.text, required: true, hint: 'e.g. 2nd term fees, PTA levy, bus'),
      const FieldSpec('amount', 'Amount', FieldType.money),
      const FieldSpec('next_due', 'Due date', FieldType.date, required: true),
      const FieldSpec('repeat', 'Repeats', FieldType.choice, options: [('termly', 'Every term'), ('yearly', 'Yearly'), ('monthly', 'Monthly'), ('once', 'Once')]),
    ], initial: {'repeat': 'termly', 'next_due': DateTime.now().add(const Duration(days: 30))});
    if (v == null) return;
    await Life.insert('bills', {
      'child_id': _childId,
      'name': '${_child?.name ?? ''}: ${v['name']}',
      'emoji': '🏫',
      'category': 'school',
      'amount': v['amount'],
      'next_due': Life.d(v['next_due'] as DateTime),
      'repeat': v['repeat'],
      'shared': true,
    });
    _load();
  }

  Future<void> _addAppointment() async {
    final v = await showFormSheet(context, title: 'Medical appointment', fields: [
      const FieldSpec('title', 'What?', FieldType.text, required: true, hint: 'e.g. Dentist, eye test, immunisation'),
      const FieldSpec('starts_at', 'When?', FieldType.datetime, required: true),
      const FieldSpec('location', 'Where?', FieldType.text),
    ], initial: {'starts_at': DateTime.now().add(const Duration(days: 7))});
    if (v == null) return;
    await Life.insert('family_events', {
      'child_id': _childId,
      'title': '${_child?.name ?? ''}: ${v['title']}',
      'emoji': '🏥',
      'starts_at': (v['starts_at'] as DateTime).toUtc().toIso8601String(),
      'location': v['location'],
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_children.isEmpty) {
      return const EmptyState(emoji: '🎒', title: 'Add your children first', subtitle: 'Go to Family → Kids and add each child.');
    }
    final exams = _tasks.where((t) => ['exam', 'homework', 'school_event'].contains(t['category']) && t['done'] != true).toList();
    final supplies = _tasks.where((t) => t['category'] == 'supplies').toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
        Wrap(spacing: 8, children: _children
            .map((c) => ChoiceChip(
                  avatar: Text(c.emoji),
                  label: Text(c.name),
                  selected: c.id == _childId,
                  onSelected: (_) {
                    setState(() => _childId = c.id);
                    _load();
                  },
                ))
            .toList()),
        SectionTitle('🗓️ Timetable', trailing: TextButton.icon(onPressed: _addClass, icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
        if (_schedule.isEmpty) const Text('Add school hours, lessons, lesson teacher, swimming or pick-up times.', style: TextStyle(color: AppColors.muted)),
        for (var d = 1; d <= 7; d++)
          if (_schedule.any((s) => s['weekday'] == d))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: WhiteCard(
                padding: const EdgeInsets.all(12),
                color: d == DateTime.now().weekday ? AppColors.primary.withValues(alpha: 0.06) : null,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 42, child: Text(_weekdays[d - 1], style: const TextStyle(fontWeight: FontWeight.w900))),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _schedule
                          .where((s) => s['weekday'] == d)
                          .map((s) => Row(children: [
                                Expanded(child: Text('${s['start_time']}${s['end_time'] != null ? '–${s['end_time']}' : ''}  ${s['title']}')),
                                GestureDetector(
                                  onTap: () async {
                                    await Life.delete('kid_schedule', '${s['id']}');
                                    _load();
                                  },
                                  child: const Icon(Icons.close, size: 16, color: AppColors.muted),
                                ),
                              ]))
                          .toList(),
                    ),
                  ),
                ]),
              ),
            ),
        SectionTitle('📝 Exams, assignments & events', trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.add),
          onSelected: _addTask,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'exam', child: Text('Exam or test')),
            PopupMenuItem(value: 'homework', child: Text('Assignment')),
            PopupMenuItem(value: 'school_event', child: Text('School event')),
          ],
        )),
        if (exams.isEmpty) const Text('Nothing coming up.', style: TextStyle(color: AppColors.muted)),
        ...exams.map((t) {
          final d = t['due_date'] == null ? null : DateTime.parse('${t['due_date']}');
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: false,
            onChanged: (_) async {
              await KidsService.setTaskDone('${t['id']}', true);
              _load();
            },
            title: Text('${const {'exam': '📝', 'homework': '📚', 'school_event': '🏫'}[t['category']]} ${t['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: d == null ? null : Text(dueLabel(d)),
          );
        }),
        SectionTitle('💳 School fees', trailing: TextButton.icon(onPressed: _addFee, icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
        if (_fees.isEmpty) const Text('Add fees and levies to get reminders before they\'re due. Pay them in Home manager → Bills.', style: TextStyle(color: AppColors.muted)),
        ..._fees.map((f) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('🏫', style: TextStyle(fontSize: 22)),
              title: Text('${f['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${f['amount'] == null ? '' : '${naira(f['amount'] as num)} · '}${dueLabel(DateTime.parse('${f['next_due']}'))}'),
            )),
        SectionTitle('🎒 Supplies checklist', trailing: TextButton.icon(onPressed: () => _addTask('supplies'), icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
        if (supplies.isEmpty) const Text('List what the school asked for: books, uniforms, crayons, lunch box...', style: TextStyle(color: AppColors.muted)),
        ...supplies.map((t) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: t['done'] == true,
              onChanged: (v) async {
                await KidsService.setTaskDone('${t['id']}', v ?? false);
                _load();
              },
              title: Text('${t['title']}', style: TextStyle(decoration: t['done'] == true ? TextDecoration.lineThrough : null)),
              secondary: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () async {
                  await KidsService.deleteTask('${t['id']}');
                  _load();
                },
              ),
            )),
        SectionTitle('🩺 Medical appointments', trailing: TextButton.icon(onPressed: _addAppointment, icon: const Icon(Icons.add, size: 18), label: const Text('Add'))),
        if (_appts.isEmpty) const Text('No upcoming appointments.', style: TextStyle(color: AppColors.muted)),
        ..._appts.map((a) {
          final d = DateTime.parse('${a['starts_at']}').toLocal();
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Text('🏥', style: TextStyle(fontSize: 22)),
            title: Text('${a['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${shortDate(d)} · ${clock(d)}${a['location'] != null ? ' · ${a['location']}' : ''}'),
          );
        }),
      ]),
    );
  }
}
