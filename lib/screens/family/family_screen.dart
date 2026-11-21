import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/family_service.dart';
import '../../core/profile_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/time_utils.dart';
import '../../widgets/ui.dart';

class FamilyScreen extends StatefulWidget {
  final int initialTab;
  const FamilyScreen({super.key, this.initialTab = 0});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  late int _tab = widget.initialTab;
  List<Profile> _members = [];
  final _cal = GlobalKey<_CalendarViewState>();
  final _chores = GlobalKey<_ChoresViewState>();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final m = await ProfileService.familyMembers(await AppSession.familyId());
      if (mounted) setState(() => _members = m);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Family hub')),
      floatingActionButton: _tab == 2
          ? null
          : FloatingActionButton(
              onPressed: () async {
                if (_tab == 0) {
                  if (await showEventSheet(context) == true) _cal.currentState?.load();
                } else {
                  if (await showChoreSheet(context, _members) == true) _chores.currentState?.load();
                }
              },
              child: const Icon(Icons.add),
            ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('Calendar')),
                ButtonSegment(value: 1, label: Text('Chores')),
                ButtonSegment(value: 2, label: Text('Shopping')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(index: _tab, children: [
            _CalendarView(key: _cal),
            _ChoresView(key: _chores, members: _members),
            const _ShoppingView(),
          ]),
        ),
      ]),
    );
  }
}

// ---------------- Calendar ----------------

const _eventEmojis = ['📅', '🎂', '🏫', '🏥', '💉', '⛪', '🕌', '🎉', '✈️', '💼', '👗', '🍽️'];

Future<bool?> showEventSheet(BuildContext context, {FamilyEvent? existing, DateTime? day}) {
  final title = TextEditingController(text: existing?.title ?? '');
  final location = TextEditingController(text: existing?.location ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  final base = day ?? DateTime.now().add(const Duration(days: 1));
  DateTime? when = existing?.startsAt ?? DateTime(base.year, base.month, base.day, 10);
  var allDay = existing?.allDay ?? false;
  var emoji = existing?.emoji ?? '📅';
  var saving = false;

  return showAppSheet<bool>(context, existing == null ? 'New family event' : 'Edit event', (ctx, setS) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _eventEmojis
            .map((e) => GestureDetector(
                  onTap: () => setS(() => emoji = e),
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: emoji == e ? AppColors.primary.withValues(alpha: 0.18) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: emoji == e ? AppColors.primary : const Color(0xFFF0E6E9)),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                ))
            .toList(),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: title,
        autofocus: existing == null,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'e.g. Clinic visit, Birthday party, PTA meeting'),
      ),
      const SizedBox(height: 10),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: allDay,
        onChanged: (v) => setS(() => allDay = v),
        title: const Text('All day', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      DateTimeButton(value: when, dateOnly: allDay, onChanged: (v) => setS(() => when = v ?? when)),
      const SizedBox(height: 10),
      TextField(
        controller: location,
        decoration: const InputDecoration(hintText: 'Where? (optional)', prefixIcon: Icon(Icons.place_outlined)),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: notes,
        minLines: 1,
        maxLines: 3,
        decoration: const InputDecoration(hintText: 'Notes (optional)'),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                if (title.text.trim().isEmpty || when == null) return;
                setS(() => saving = true);
                try {
                  final w = when!;
                  await FamilyService.saveEvent(
                    id: existing?.id,
                    title: title.text,
                    startsAt: allDay ? DateTime(w.year, w.month, w.day, 8) : w,
                    allDay: allDay,
                    location: location.text,
                    notes: notes.text,
                    emoji: emoji,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (_) {
                  setS(() => saving = false);
                  if (ctx.mounted) toast(ctx, 'Could not save. Please try again.');
                }
              },
        child: const Text('Save event'),
      ),
    ]);
  });
}

class _CalendarView extends StatefulWidget {
  const _CalendarView({super.key});
  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  List<FamilyEvent> _events = [];
  bool _loading = true;
  DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final e = await FamilyService.events();
      if (mounted) {
        setState(() {
          _events = e;
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
    final t = Theme.of(context).textTheme;
    final now = DateTime.now();
    final days = List.generate(21, (i) => DateTime(now.year, now.month, now.day + i));
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayEvents = _events.where((e) => isSameDay(e.startsAt, _selected)).toList();
    final upcoming = _events.where((e) => !e.startsAt.isBefore(DateTime(now.year, now.month, now.day))).take(30).toList();

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 100),
        children: [
          SizedBox(
            height: 84,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: days.length,
              itemBuilder: (context, i) {
                final d = days[i];
                final sel = isSameDay(d, _selected);
                final has = _events.any((e) => isSameDay(e.startsAt, d));
                return GestureDetector(
                  onTap: () => setState(() => _selected = d),
                  child: Container(
                    width: 54,
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(wd[d.weekday - 1],
                          style: TextStyle(fontSize: 12, color: sel ? Colors.white70 : AppColors.muted, fontWeight: FontWeight.w700)),
                      Text('${d.day}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: sel ? Colors.white : AppColors.ink)),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: has ? (sel ? Colors.white : AppColors.primary) : Colors.transparent,
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle(
                isSameDay(_selected, now) ? 'Today' : shortDate(_selected),
                trailing: TextButton.icon(
                  onPressed: () async {
                    if (await showEventSheet(context, day: _selected) == true) load();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ),
              if (dayEvents.isEmpty)
                Text('Nothing planned.', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
              ...dayEvents.map(_tile),
              if (upcoming.isNotEmpty) ...[
                const SectionTitle('Coming up'),
                ...upcoming.map(_tile),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _tile(FamilyEvent e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: WhiteCard(
        padding: const EdgeInsets.all(12),
        onTap: () async {
          if (await showEventSheet(context, existing: e) == true) load();
        },
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Text(e.emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(
                '${shortDate(e.startsAt)}${e.allDay ? ' · All day' : ' · ${clock(e.startsAt)}'}${e.location != null ? ' · ${e.location}' : ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.muted),
            onPressed: () async {
              if (await confirmDelete(context, 'Delete ${e.title}?')) {
                await FamilyService.deleteEvent(e.id);
                load();
              }
            },
          ),
        ]),
      ),
    );
  }
}

// ---------------- Chores ----------------

Future<bool?> showChoreSheet(BuildContext context, List<Profile> members, {Chore? existing}) {
  final title = TextEditingController(text: existing?.title ?? '');
  String? assignee = existing?.assignee;
  DateTime? due = existing?.dueDate ?? DateTime.now();
  var repeat = existing?.repeat ?? 'none';
  var saving = false;

  return showAppSheet<bool>(context, existing == null ? 'New chore' : 'Edit chore', (ctx, setS) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: title,
        autofocus: existing == null,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'e.g. Wash baby bottles, School run, Take out the bin'),
      ),
      const SizedBox(height: 14),
      const Text('Who does it?', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      ChipChoices<String?>(
        options: [(null, '🙋 Anyone'), ...members.map((m) => (m.id, '${m.avatar} ${m.displayName}'))],
        value: assignee,
        onChanged: (v) => setS(() => assignee = v),
      ),
      const SizedBox(height: 14),
      DateTimeButton(value: due, dateOnly: true, allowClear: true, emptyLabel: 'No due date', onChanged: (v) => setS(() => due = v)),
      const SizedBox(height: 10),
      ChipChoices<String>(
        options: const [('none', 'Once'), ('daily', 'Every day'), ('weekly', 'Every week')],
        value: repeat,
        onChanged: (v) => setS(() => repeat = v),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                if (title.text.trim().isEmpty) return;
                setS(() => saving = true);
                try {
                  await FamilyService.saveChore(id: existing?.id, title: title.text, assignee: assignee, dueDate: due, repeat: repeat);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (_) {
                  setS(() => saving = false);
                  if (ctx.mounted) toast(ctx, 'Could not save. Please try again.');
                }
              },
        child: const Text('Save chore'),
      ),
    ]);
  });
}

class _ChoresView extends StatefulWidget {
  final List<Profile> members;
  const _ChoresView({super.key, required this.members});
  @override
  State<_ChoresView> createState() => _ChoresViewState();
}

class _ChoresViewState extends State<_ChoresView> {
  List<Chore> _items = [];
  bool _loading = true;
  String _filter = 'all';
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    load();
    _channel = supa
        .channel('chores-live')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'chores', callback: (_) => load())
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) supa.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> load() async {
    try {
      final c = await FamilyService.chores();
      if (mounted) {
        setState(() {
          _items = c;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Profile? _member(String? id) => widget.members.where((m) => m.id == id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    var open = _items.where((c) => !c.done).toList();
    if (_filter == 'mine') open = open.where((c) => c.assignee == AppSession.uid || c.assignee == null).toList();
    final done = _items.where((c) => c.done).take(10).toList();

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          ChipChoices<String>(
            options: const [('all', 'All chores'), ('mine', 'Mine + anyone')],
            value: _filter,
            onChanged: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 8),
          if (open.isEmpty)
            const EmptyState(emoji: '🧺', title: 'No chores waiting', subtitle: 'Add chores and share the load with your partner.'),
          ...open.map(_tile),
          if (done.isNotEmpty) ...[const SectionTitle('Done'), ...done.map(_tile)],
        ],
      ),
    );
  }

  Widget _tile(Chore c) {
    final who = _member(c.assignee);
    final today = DateTime.now();
    final overdue = !c.done && c.dueDate != null && c.dueDate!.isBefore(DateTime(today.year, today.month, today.day));
    final doneBy = _member(c.doneBy);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: WhiteCard(
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
        onTap: () async {
          if (await showChoreSheet(context, widget.members, existing: c) == true) load();
        },
        child: Row(children: [
          Checkbox(
            value: c.done,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onChanged: (_) async {
              await FamilyService.setChoreDone(c.id, !c.done);
              if (!c.done && mounted) toast(context, 'Chore done! +4 XP');
              load();
            },
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: c.done ? TextDecoration.lineThrough : null,
                    color: c.done ? AppColors.muted : AppColors.ink,
                  )),
              Text(
                [
                  who == null ? 'Anyone' : '${who.avatar} ${who.displayName}',
                  if (c.dueDate != null) (overdue ? 'Overdue' : (isSameDay(c.dueDate!, today) ? 'Today' : shortDate(c.dueDate!))),
                  if (c.repeat != 'none') (c.repeat == 'daily' ? 'Every day' : 'Every week'),
                  if (c.done && doneBy != null) 'Done by ${doneBy.displayName}',
                ].join(' · '),
                style: TextStyle(fontSize: 12, color: overdue ? Colors.red.shade400 : AppColors.muted),
              ),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.muted),
            onPressed: () async {
              if (await confirmDelete(context, 'Delete this chore?', message: c.title)) {
                await FamilyService.deleteChore(c.id);
                load();
              }
            },
          ),
        ]),
      ),
    );
  }
}

// ---------------- Shopping ----------------

class _ShoppingView extends StatefulWidget {
  const _ShoppingView();
  @override
  State<_ShoppingView> createState() => _ShoppingViewState();
}

class _ShoppingViewState extends State<_ShoppingView> {
  final _name = TextEditingController();
  final _qty = TextEditingController();
  String _cat = 'food';
  List<ShoppingItem> _items = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    load();
    _channel = supa
        .channel('shopping-live')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'shopping_items', callback: (_) => load())
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) supa.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> load() async {
    try {
      final i = await FamilyService.shopping();
      if (mounted) {
        setState(() {
          _items = i;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty) return;
    final n = _name.text, q = _qty.text;
    _name.clear();
    _qty.clear();
    try {
      await FamilyService.addItem(n, q, _cat);
      load();
    } catch (_) {
      if (mounted) toast(context, 'Could not add. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final open = _items.where((i) => !i.checked).toList();
    final got = _items.where((i) => i.checked).toList();
    final byCat = <String, List<ShoppingItem>>{};
    for (final i in open) {
      byCat.putIfAbsent(i.category, () => []).add(i);
    }

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        children: [
          WhiteCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(hintText: 'Add item (e.g. diapers)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _qty,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(hintText: 'Qty'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
              ]),
              const SizedBox(height: 10),
              ChipChoices<String>(options: shoppingCategories, value: _cat, onChanged: (v) => setState(() => _cat = v)),
            ]),
          ),
          const SizedBox(height: 4),
          if (open.isEmpty && got.isEmpty)
            const EmptyState(emoji: '🛒', title: 'Shopping list is empty', subtitle: 'Items you add show on your partner\'s phone instantly.'),
          ...shoppingCategories.where((c) => byCat.containsKey(c.$1)).expand((c) => [
                SectionTitle(c.$2),
                ...byCat[c.$1]!.map(_tile),
              ]),
          if (got.isNotEmpty) ...[
            SectionTitle(
              '✅ In the basket (${got.length})',
              trailing: TextButton(
                onPressed: () async {
                  await FamilyService.clearChecked();
                  load();
                },
                child: const Text('Clear'),
              ),
            ),
            ...got.map(_tile),
          ],
        ],
      ),
    );
  }

  Widget _tile(ShoppingItem i) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: WhiteCard(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        onTap: () async {
          await FamilyService.setChecked(i.id, !i.checked);
          load();
        },
        child: Row(children: [
          Checkbox(
            value: i.checked,
            shape: const CircleBorder(),
            onChanged: (_) async {
              await FamilyService.setChecked(i.id, !i.checked);
              load();
            },
          ),
          Expanded(
            child: Text(
              i.qty == null ? i.name : '${i.name}  ·  ${i.qty}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                decoration: i.checked ? TextDecoration.lineThrough : null,
                color: i.checked ? AppColors.muted : AppColors.ink,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
            onPressed: () async {
              await FamilyService.deleteItem(i.id);
              load();
            },
          ),
        ]),
      ),
    );
  }
}
