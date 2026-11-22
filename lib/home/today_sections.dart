import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../core/family_service.dart';
import '../core/life_service.dart';
import '../core/profile_service.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../health/symptom_checker_screen.dart';
import '../me/journal_screen.dart';
import '../me/me_screen.dart';
import '../me/pocket_screen.dart';
import '../meals/dishes.dart';
import '../meals/meals_screen.dart';
import '../meals/meals_service.dart';
import '../screens/memory/reminders_view.dart';
import '../widgets/form_sheet.dart';
import '../widgets/ui.dart';

class TodayDateLine extends StatelessWidget {
  const TodayDateLine({super.key});
  @override
  Widget build(BuildContext context) {
    const days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
    const months = ['JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'];
    final n = DateTime.now();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${days[n.weekday - 1]}, ${months[n.month - 1]} ${n.day}',
          style: const TextStyle(letterSpacing: 1.4, fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary)),
      const Text("Here's your plan for today.", style: TextStyle(color: AppColors.muted)),
    ]);
  }
}

/// AI-written summary of her day. Generated once per day and cached on the phone.
class AiSummaryCard extends StatefulWidget {
  final VoidCallback onAsk;
  const AiSummaryCard({super.key, required this.onAsk});
  @override
  State<AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends State<AiSummaryCard> {
  String? _text;
  bool _loading = false;

  String get _key => 'momos_ai_summary_${supa.auth.currentUser?.id}_${dateKey(DateTime.now())}';

  @override
  void initState() {
    super.initState();
    try {
      _text = web.window.localStorage.getItem(_key);
    } catch (_) {}
    if (_text == null) _generate();
  }

  Future<void> _generate() async {
    setState(() => _loading = true);
    try {
      final r = await supa.functions.invoke('assistant', body: {'mode': 'summary'});
      final d = r.data is String ? jsonDecode(r.data as String) : r.data;
      final txt = (d['reply'] ?? '') as String;
      if (txt.isNotEmpty) {
        _text = txt;
        try {
          web.window.localStorage.setItem(_key, txt);
        } catch (_) {}
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.secondary.withValues(alpha: 0.14), AppColors.primary.withValues(alpha: 0.12)]),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('✨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          const Expanded(child: Text('Your day at a glance', style: TextStyle(fontWeight: FontWeight.w900))),
          if (!_loading)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Refresh',
              onPressed: _generate,
              icon: const Icon(Icons.refresh, size: 18),
            ),
        ]),
        const SizedBox(height: 4),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(minHeight: 3),
          )
        else
          Text(_text ?? 'Tap refresh to get a short plan for your day.', style: const TextStyle(height: 1.4)),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(onPressed: widget.onAsk, icon: const Icon(Icons.mic, size: 18), label: const Text('Ask your assistant')),
        ),
      ]),
    );
  }
}

class QuickActions extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  final VoidCallback onChanged;
  const QuickActions({super.key, required this.onNavigate, required this.onChanged});

  Future<void> _addShopping(BuildContext context) async {
    final v = await showFormSheet(context, title: 'Add to shopping list', fields: [
      const FieldSpec('name', 'Item', FieldType.text, required: true, hint: 'e.g. Cooking gas, diapers'),
      const FieldSpec('qty', 'Quantity (optional)', FieldType.text),
      FieldSpec('category', 'Category', FieldType.choice, options: shoppingCategories),
    ], initial: {'category': 'food'});
    if (v == null) return;
    await FamilyService.addItem(v['name'] as String, v['qty'] as String?, (v['category'] ?? 'other') as String);
    if (context.mounted) toast(context, 'Added to the family shopping list 🛒');
  }

  @override
  Widget build(BuildContext context) {
    final actions = <(String, String, Future<void> Function())>[
      ('⏰', 'Reminder', () async {
        if (await showReminderSheet(context) == true) onChanged();
      }),
      ('💸', 'Expense', () async {
        if (await showTransactionSheet(context) == true) onChanged();
      }),
      ('🛒', 'Shopping', () => _addShopping(context)),
      ('🎙️', 'Ask AI', () async => onNavigate(4)),
      ('📔', 'Journal', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JournalEditor()))),
      ('🩺', 'Symptoms', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SymptomCheckerScreen()))),
      ('💗', 'Me', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeScreen()))),
      ('🍲', 'Meals', () async => onNavigate(2)),
    ];
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: actions
          .map((a) => WhiteCard(
                padding: EdgeInsets.zero,
                onTap: a.$3,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(a.$1, style: const TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text(a.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ]),
              ))
          .toList(),
    );
  }
}

/// Today's meals, household jobs, children's activities, goals, shopping and bills.
class TodaySections extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final int refresh;
  const TodaySections({super.key, required this.onNavigate, required this.refresh});
  @override
  State<TodaySections> createState() => _TodaySectionsState();
}

class _TodaySectionsState extends State<TodaySections> {
  Map<String, String>? _meals;
  List<Rec> _house = [], _schedule = [], _kidTasks = [], _goals = [], _bills = [], _low = [], _expiring = [];
  Set<String> _goalDone = {};
  Map<String, String> _childNames = {};
  int _shopping = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TodaySections old) {
    super.didUpdateWidget(old);
    if (old.refresh != widget.refresh) _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final today = dateKey(now);
    final soon = dateKey(now.add(const Duration(days: 1)));
    Future<T?> safe<T>(Future<T> f) async {
      try {
        return await f;
      } catch (_) {
        return null;
      }
    }

    final r = await Future.wait([
      safe(MealsService.load(MealsService.weekStart(now))),
      safe(Life.list('household_tasks', order: 'next_due')),
      safe(Life.list('kid_schedule', eq: {'weekday': now.weekday}, order: 'start_time')),
      safe(Life.list('kid_tasks', eq: {'done': false}, order: 'due_date')),
      safe(Life.list('goals', eq: {'period': 'daily', 'done': false, 'user_id': supa.auth.currentUser?.id})),
      safe(Life.list('goal_checkins', eq: {'day': today})),
      safe(Life.list('bills', order: 'next_due')),
      safe(Life.list('inventory_items')),
      safe(Life.list('shopping_items', eq: {'checked': false, 'archived': false}, select: 'id')),
      safe(Life.list('children', select: 'id,name')),
    ]);
    if (!mounted) return;
    setState(() {
      final plan = r[0] as MealPlan?;
      _meals = plan?['${now.weekday - 1}'];
      _house = ((r[1] as List<Rec>?) ?? []).where((h) => '${h['next_due']}'.compareTo(today) <= 0).toList();
      _schedule = (r[2] as List<Rec>?) ?? [];
      _kidTasks = ((r[3] as List<Rec>?) ?? [])
          .where((k) => k['due_date'] != null && '${k['due_date']}'.compareTo(soon) <= 0)
          .toList();
      _goals = (r[4] as List<Rec>?) ?? [];
      _goalDone = ((r[5] as List<Rec>?) ?? []).map((g) => '${g['goal_id']}').toSet();
      _bills = ((r[6] as List<Rec>?) ?? [])
          .where((b) => '${b['next_due']}'.compareTo(dateKey(now.add(const Duration(days: 3)))) <= 0)
          .toList();
      final inv = (r[7] as List<Rec>?) ?? [];
      _low = inv.where((i) => i['low_at'] != null && (i['qty'] as num) <= (i['low_at'] as num)).toList();
      _expiring = inv
          .where((i) => i['expires_on'] != null && '${i['expires_on']}'.compareTo(dateKey(now.add(const Duration(days: 3)))) <= 0)
          .toList();
      _shopping = ((r[8] as List<Rec>?) ?? []).length;
      _childNames = {for (final c in (r[9] as List<Rec>?) ?? []) '${c['id']}': '${c['name']}'};
    });
  }

  Widget _card(String title, String? action, VoidCallback? onAction, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            if (action != null) TextButton(onPressed: onAction, child: Text(action)),
          ]),
          ...children,
        ]),
      ),
    );
  }

  Widget _line(String emoji, String text, {String? trailing, Color? trailingColor, VoidCallback? onTap, Widget? action}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(trailing, style: TextStyle(fontSize: 12, color: trailingColor ?? AppColors.muted, fontWeight: FontWeight.w700)),
            ),
          ?action,
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];

    // Meals
    if (_meals != null) {
      widgets.add(_card("Today's meals", 'Kitchen', () => widget.onNavigate(2), [
        for (final (slot, label) in [('b', 'Breakfast'), ('l', 'Lunch'), ('d', 'Dinner')])
          if (dishByKey(_meals![slot] ?? '') case final dish?)
            InkWell(
              onTap: () => showDishSheet(context, dish),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  SizedBox(width: 44, height: 44, child: DishImage(dish, radius: 12, emojiSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1, color: AppColors.primary, fontWeight: FontWeight.w900)),
                      Text(dish.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  Text('${dish.minutes} min', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(width: 8),
                ]),
              ),
            ),
      ]));
    } else {
      widgets.add(_card("Today's meals", 'Plan meals', () => widget.onNavigate(2), [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('No meal plan yet. Plan the week in one tap in the Kitchen.', style: TextStyle(color: AppColors.muted)),
        ),
      ]));
    }

    // Household
    if (_house.isNotEmpty) {
      widgets.add(_card('Household today', 'See all', () => widget.onNavigate(3), [
        ..._house.take(5).map((h) {
          final overdue = '${h['next_due']}'.compareTo(dateKey(DateTime.now())) < 0;
          return _line('${h['emoji']}', '${h['title']}',
              trailing: overdue ? 'Overdue' : 'Today',
              trailingColor: overdue ? Colors.red.shade400 : null,
              action: IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.check_circle_outline, color: AppColors.mint),
                onPressed: () async {
                  await Life.rpc('complete_household_task', {'p_id': h['id']});
                  if (context.mounted) toast(context, 'Done! +4 XP');
                  _load();
                },
              ));
        }),
      ]));
    }

    // Children
    if (_schedule.isNotEmpty || _kidTasks.isNotEmpty) {
      widgets.add(_card("Children's day", 'Family', () => widget.onNavigate(3), [
        ..._schedule.take(5).map((s) => _line('🏫', '${_childNames[s['child_id']] ?? ''}: ${s['title']}', trailing: '${s['start_time']}')),
        ..._kidTasks.take(4).map((k) {
          final due = DateTime.tryParse('${k['due_date']}');
          return _line(
            const {'homework': '📚', 'exam': '📝', 'school_event': '🏫', 'supplies': '🎒', 'medical': '🩺', 'activity': '⚽'}[k['category']] ?? '📌',
            '${_childNames[k['child_id']] ?? ''}: ${k['title']}',
            trailing: due == null ? null : dueLabel(due),
          );
        }),
      ]));
    }

    // Goals
    if (_goals.isNotEmpty) {
      widgets.add(_card('Daily goals', null, null, [
        ..._goals.map((g) {
          final done = _goalDone.contains('${g['id']}');
          return _line('${g['emoji']}', '${g['title']}',
              action: IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? AppColors.mint : AppColors.muted),
                onPressed: done
                    ? null
                    : () async {
                        await Life.rpc('goal_progress', {'p_id': g['id']});
                        if (context.mounted) toast(context, 'Goal done for today! +5 XP');
                        _load();
                      },
              ));
        }),
      ]));
    }

    // Shopping, stock and bills
    final money = <Widget>[
      if (_shopping > 0) _line('🛒', '$_shopping item${_shopping == 1 ? '' : 's'} on the shopping list', onTap: () => widget.onNavigate(2)),
      if (_low.isNotEmpty) _line('📉', 'Running low: ${_low.take(3).map((i) => i['name']).join(', ')}', onTap: () => widget.onNavigate(2)),
      if (_expiring.isNotEmpty)
        _line('⏳', 'Use soon: ${_expiring.take(3).map((i) => i['name']).join(', ')}', trailingColor: Colors.orange, onTap: () => widget.onNavigate(2)),
      ..._bills.take(3).map((b) {
        final due = DateTime.parse('${b['next_due']}');
        return _line('${b['emoji']}', '${b['name']}${b['amount'] != null ? ' · ${naira(b['amount'] as num)}' : ''}',
            trailing: dueLabel(due), trailingColor: due.isBefore(DateTime.now()) ? Colors.red.shade400 : null);
      }),
    ];
    if (money.isNotEmpty) {
      widgets.add(_card('Shopping & bills', null, null, money));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets);
  }
}
