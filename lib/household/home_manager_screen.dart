import 'package:material_ui/material_ui.dart';

import '../core/family_service.dart';
import '../core/life_service.dart';
import '../core/profile_service.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../widgets/form_sheet.dart';
import '../widgets/ui.dart';

const _areas = <(String, String)>[
  ('cleaning', '🧹 Cleaning'),
  ('laundry', '🧺 Laundry'),
  ('kitchen', '🍳 Kitchen'),
  ('maintenance', '🔧 Maintenance'),
  ('garden', '🌿 Compound'),
  ('other', '📌 Other'),
];
const _freq = <(String, String)>[('daily', 'Daily'), ('weekly', 'Weekly'), ('monthly', 'Monthly'), ('once', 'Once')];

/// Ready-made household jobs she can add in one tap.
const _templates = <(String, String, String, String)>[
  ('🧹', 'Sweep and mop the floors', 'cleaning', 'daily'),
  ('🍽️', 'Wash dishes', 'kitchen', 'daily'),
  ('🗑️', 'Take out the waste bin', 'cleaning', 'daily'),
  ('🧺', 'Wash clothes', 'laundry', 'weekly'),
  ('👕', 'Iron school uniforms', 'laundry', 'weekly'),
  ('🛏️', 'Change bed sheets', 'laundry', 'weekly'),
  ('🚽', 'Clean the bathroom and toilet', 'cleaning', 'weekly'),
  ('🧊', 'Clean the fridge', 'kitchen', 'monthly'),
  ('🪟', 'Dust the windows and fans', 'cleaning', 'weekly'),
  ('🔌', 'Service the generator', 'maintenance', 'monthly'),
  ('💧', 'Wash the water tank', 'maintenance', 'monthly'),
  ('🦟', 'Fumigate / spray for mosquitoes', 'maintenance', 'monthly'),
  ('🍼', 'Sterilise baby bottles', 'kitchen', 'daily'),
];

class HomeManagerScreen extends StatefulWidget {
  final int initialTab;
  const HomeManagerScreen({super.key, this.initialTab = 0});
  @override
  State<HomeManagerScreen> createState() => _HomeManagerScreenState();
}

class _HomeManagerScreenState extends State<HomeManagerScreen> {
  late int _tab = widget.initialTab;
  List<Rec> _tasks = [], _bills = [], _utils = [], _supplies = [], _appliances = [];
  List<Profile> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([
        Life.list('household_tasks', order: 'next_due'),
        Life.list('bills', order: 'next_due'),
        Life.list('utility_logs', order: 'logged_on', ascending: false, limit: 200),
        Life.list('inventory_items', order: 'name'),
        Life.list('appliances', order: 'name'),
      ]);
      final m = await ProfileService.familyMembers(await AppSession.familyId());
      if (mounted) {
        setState(() {
          _tasks = r[0];
          _bills = r[1];
          _utils = r[2];
          _supplies = r[3].where((i) => ['household', 'bathroom', 'baby'].contains(i['place'])).toList();
          _appliances = r[4];
          _members = m;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Jobs ----------
  Future<void> _editTask([Rec? t]) async {
    final v = await showFormSheet(context, title: t == null ? 'New household job' : 'Edit job', fields: [
      const FieldSpec('emoji', 'Icon', FieldType.emoji),
      const FieldSpec('title', 'Job', FieldType.text, required: true, hint: 'e.g. Wash curtains'),
      const FieldSpec('area', 'Area', FieldType.choice, options: _areas),
      const FieldSpec('frequency', 'How often?', FieldType.choice, options: _freq),
      const FieldSpec('next_due', 'Next due', FieldType.date, required: true),
      FieldSpec('assignee', 'Who does it?', FieldType.choice, options: [('', 'Anyone'), ..._members.map((m) => (m.id, m.displayName))]),
    ], initial: {
      'emoji': t?['emoji'] ?? '🧹',
      'title': t?['title'],
      'area': t?['area'] ?? 'cleaning',
      'frequency': t?['frequency'] ?? 'weekly',
      'next_due': Life.parseDate(t?['next_due']) ?? DateTime.now(),
      'assignee': t?['assignee'] ?? '',
    }, emojis: const ['🧹', '🧺', '🍽️', '🗑️', '🚽', '🛏️', '🪟', '🔧', '🔌', '💧', '🌿', '🧊']);
    if (v == null) return;
    final data = {
      'emoji': v['emoji'],
      'title': v['title'],
      'area': v['area'],
      'frequency': v['frequency'],
      'next_due': Life.d(v['next_due'] as DateTime),
      'assignee': (v['assignee'] ?? '') == '' ? null : v['assignee'],
    };
    t == null ? await Life.insert('household_tasks', data) : await Life.update('household_tasks', '${t['id']}', data);
    _load();
  }

  Future<void> _addTemplates() async {
    final existing = _tasks.map((t) => '${t['title']}'.toLowerCase()).toSet();
    final options = _templates.where((t) => !existing.contains(t.$2.toLowerCase())).toList();
    final picked = <int>{};
    final ok = await showAppSheet<bool>(context, 'Quick add common jobs', (ctx, setS) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...options.asMap().entries.map((e) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: picked.contains(e.key),
              onChanged: (v) => setS(() => v == true ? picked.add(e.key) : picked.remove(e.key)),
              title: Text('${e.value.$1} ${e.value.$2}'),
              subtitle: Text(_freq.firstWhere((f) => f.$1 == e.value.$4).$2),
            )),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () async {
            for (final i in picked) {
              final t = options[i];
              await Life.insert('household_tasks', {'emoji': t.$1, 'title': t.$2, 'area': t.$3, 'frequency': t.$4, 'next_due': Life.d(DateTime.now())});
            }
            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: Text('Add ${picked.length} job${picked.length == 1 ? '' : 's'}'),
        ),
      ]);
    });
    if (ok == true) _load();
  }

  // ---------- Bills ----------
  Future<void> _editBill([Rec? b]) async {
    final v = await showFormSheet(context, title: b == null ? 'New bill' : 'Edit bill', fields: [
      const FieldSpec('emoji', 'Icon', FieldType.emoji),
      const FieldSpec('name', 'Bill', FieldType.text, required: true, hint: 'e.g. Electricity (prepaid), DSTV, House rent'),
      const FieldSpec('category', 'Type', FieldType.choice, options: [
        ('electricity', 'Electricity'), ('water', 'Water'), ('gas', 'Cooking gas'), ('internet', 'Internet / data'), ('tv', 'TV'), ('phone', 'Phone'),
        ('rent', 'Rent'), ('school', 'School fees'), ('health', 'Health / HMO'), ('other', 'Other'),
      ]),
      const FieldSpec('amount', 'Usual amount', FieldType.money),
      const FieldSpec('next_due', 'Next due date', FieldType.date, required: true),
      const FieldSpec('repeat', 'Repeats', FieldType.choice, options: [('monthly', 'Monthly'), ('termly', 'Every term'), ('yearly', 'Yearly'), ('once', 'Once')]),
      const FieldSpec('shared', 'Household bill (share with family)', FieldType.toggle),
      const FieldSpec('notes', 'Notes (meter number, account, etc.)', FieldType.text),
    ], initial: {
      'emoji': b?['emoji'] ?? '🧾',
      'name': b?['name'],
      'category': b?['category'] ?? 'electricity',
      'amount': b?['amount'],
      'next_due': Life.parseDate(b?['next_due']) ?? DateTime.now().add(const Duration(days: 7)),
      'repeat': b?['repeat'] ?? 'monthly',
      'shared': b?['shared'] ?? true,
      'notes': b?['notes'],
    }, emojis: const ['🧾', '💡', '💧', '🔥', '📶', '📺', '📱', '🏠', '🏫', '🏥', '🚗', '💳']);
    if (v == null) return;
    final data = {
      'emoji': v['emoji'],
      'name': v['name'],
      'category': v['category'],
      'amount': v['amount'],
      'next_due': Life.d(v['next_due'] as DateTime),
      'repeat': v['repeat'],
      'shared': v['shared'] ?? true,
      'notes': v['notes'],
    };
    b == null ? await Life.insert('bills', data) : await Life.update('bills', '${b['id']}', data);
    _load();
  }

  Future<void> _payBill(Rec b) async {
    final v = await showFormSheet(context, title: 'Pay ${b['name']}', saveLabel: 'Mark as paid', fields: [
      const FieldSpec('amount', 'Amount paid', FieldType.money, required: true),
      const FieldSpec('log', 'Also add to MyPocket expenses', FieldType.toggle),
    ], initial: {'amount': b['amount'], 'log': true});
    if (v == null) return;
    try {
      await Life.rpc('pay_bill', {'p_id': b['id'], 'p_amount': v['amount'], 'p_log_expense': v['log'] ?? true});
      if (mounted) toast(context, 'Paid ✅ Next due date set. +3 XP');
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Please try again.');
    }
    _load();
  }

  // ---------- Utilities ----------
  Future<void> _logUtility() async {
    final v = await showFormSheet(context, title: 'Log a utility top-up', fields: [
      const FieldSpec('kind', 'What?', FieldType.choice, options: [('electricity', '💡 Electricity units'), ('gas', '🔥 Cooking gas refill'), ('fuel', '⛽ Generator fuel'), ('water', '💧 Water')]),
      const FieldSpec('units', 'Units / kg / litres (optional)', FieldType.number),
      const FieldSpec('amount', 'Amount paid', FieldType.money),
      const FieldSpec('logged_on', 'Date', FieldType.date, required: true),
      const FieldSpec('note', 'Note (optional)', FieldType.text),
    ], initial: {'kind': 'electricity', 'logged_on': DateTime.now()});
    if (v == null) return;
    await Life.insert('utility_logs', {
      'kind': v['kind'],
      'units': v['units'],
      'amount': v['amount'],
      'logged_on': Life.d(v['logged_on'] as DateTime),
      'note': v['note'],
    });
    _load();
  }

  // ---------- Supplies ----------
  Future<void> _editSupply([Rec? s]) async {
    final v = await showFormSheet(context, title: s == null ? 'Add household supply' : 'Update ${s['name']}', fields: [
      const FieldSpec('name', 'Item', FieldType.text, required: true, hint: 'e.g. Detergent, tissue, diapers'),
      const FieldSpec('place', 'Where?', FieldType.choice, options: [('household', 'Household'), ('bathroom', 'Bathroom'), ('baby', 'Baby')]),
      const FieldSpec('qty', 'How many left?', FieldType.number, required: true),
      const FieldSpec('unit', 'Unit', FieldType.text, hint: 'packs, bottles, rolls'),
      const FieldSpec('low_at', 'Remind me to restock at', FieldType.number, hint: 'e.g. 1'),
      const FieldSpec('price', 'Usual price', FieldType.money),
    ], initial: {
      'name': s?['name'],
      'place': s?['place'] ?? 'household',
      'qty': s?['qty'] ?? 1,
      'unit': s?['unit'],
      'low_at': s?['low_at'] ?? 1,
      'price': s?['price'],
    });
    if (v == null) return;
    final data = {'name': v['name'], 'place': v['place'], 'qty': v['qty'], 'unit': v['unit'], 'low_at': v['low_at'], 'price': v['price']};
    s == null ? await Life.insert('inventory_items', data) : await Life.update('inventory_items', '${s['id']}', data);
    _load();
  }

  Future<void> _changeQty(Rec s, num by) async {
    final q = ((s['qty'] as num) + by).clamp(0, 9999);
    await Life.update('inventory_items', '${s['id']}', {'qty': q});
    if (s['low_at'] != null && q <= (s['low_at'] as num) && (s['qty'] as num) > (s['low_at'] as num) && mounted) {
      final add = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${s['name']} is running low'),
          content: const Text('Add it to the shopping list?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      );
      if (add == true) await FamilyService.addItem('${s['name']}', null, s['place'] == 'baby' ? 'baby' : 'household');
    }
    _load();
  }

  // ---------- Appliances ----------
  Future<void> _editAppliance([Rec? a]) async {
    final v = await showFormSheet(context, title: a == null ? 'Add appliance' : 'Edit ${a['name']}', fields: [
      const FieldSpec('emoji', 'Icon', FieldType.emoji),
      const FieldSpec('name', 'Appliance', FieldType.text, required: true, hint: 'e.g. Generator, fridge, AC, washing machine'),
      const FieldSpec('brand', 'Brand / model', FieldType.text),
      const FieldSpec('bought_on', 'Bought on', FieldType.date),
      const FieldSpec('warranty_until', 'Warranty until', FieldType.date),
      const FieldSpec('last_service', 'Last serviced', FieldType.date),
      const FieldSpec('service_every_months', 'Service every (months)', FieldType.number),
      const FieldSpec('notes', 'Notes (repairer phone, issues)', FieldType.multiline),
    ], initial: {
      'emoji': a?['emoji'] ?? '🔌',
      'name': a?['name'],
      'brand': a?['brand'],
      'bought_on': Life.parseDate(a?['bought_on']),
      'warranty_until': Life.parseDate(a?['warranty_until']),
      'last_service': Life.parseDate(a?['last_service']),
      'service_every_months': a?['service_every_months'],
      'notes': a?['notes'],
    }, emojis: const ['🔌', '⚡', '🧊', '❄️', '📺', '🧺', '🍳', '🌀', '💡', '🚗', '🖥️', '🔥']);
    if (v == null) return;
    String? dd(dynamic x) => x == null ? null : Life.d(x as DateTime);
    final data = {
      'emoji': v['emoji'],
      'name': v['name'],
      'brand': v['brand'],
      'bought_on': dd(v['bought_on']),
      'warranty_until': dd(v['warranty_until']),
      'last_service': dd(v['last_service']),
      'service_every_months': (v['service_every_months'] as num?)?.toInt(),
      'notes': v['notes'],
    };
    a == null ? await Life.insert('appliances', data) : await Life.update('appliances', '${a['id']}', data);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home manager 🏠')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => switch (_tab) {
          0 => _editTask(),
          1 => _editBill(),
          2 => _logUtility(),
          3 => _editSupply(),
          _ => _editAppliance(),
        },
        child: const Icon(Icons.add),
      ),
      body: Column(children: [
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), children: [
            for (final (i, l) in const [(0, '🧹 Jobs'), (1, '🧾 Bills'), (2, '💡 Utilities'), (3, '🧴 Supplies'), (4, '🔌 Appliances')])
              Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(l), selected: _tab == i, onSelected: (_) => setState(() => _tab = i))),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: switch (_tab) {
                    0 => _jobsView(),
                    1 => _billsView(),
                    2 => _utilView(),
                    3 => _suppliesView(),
                    _ => _appliancesView(),
                  }),
                ),
        ),
      ]),
    );
  }

  List<Widget> _jobsView() {
    final today = dateKey(DateTime.now());
    final due = _tasks.where((t) => '${t['next_due']}'.compareTo(today) <= 0).toList();
    final later = _tasks.where((t) => '${t['next_due']}'.compareTo(today) > 0).toList();
    final doneThisWeek = _tasks.where((t) => t['last_done'] != null && DateTime.now().difference(DateTime.parse('${t['last_done']}')).inDays < 7).length;
    Widget tile(Rec t) {
      final who = _members.where((m) => m.id == t['assignee']).firstOrNull;
      final d = DateTime.parse('${t['next_due']}');
      final overdue = '${t['next_due']}'.compareTo(today) < 0;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: WhiteCard(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          onTap: () => _editTask(t),
          child: Row(children: [
            Text('${t['emoji']}', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(
                  [
                    _freq.firstWhere((f) => f.$1 == t['frequency']).$2,
                    dueLabel(d),
                    who == null ? 'Anyone' : who.displayName,
                    if (t['last_done'] != null) 'last done ${timeAgo(DateTime.parse('${t['last_done']}').toLocal())}',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: overdue ? Colors.red.shade400 : AppColors.muted),
                ),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline, color: AppColors.mint, size: 30),
              onPressed: () async {
                await Life.rpc('complete_household_task', {'p_id': t['id']});
                if (mounted) toast(context, t['frequency'] == 'once' ? 'Done! +4 XP' : 'Done! Next one is scheduled. +4 XP');
                _load();
              },
            ),
          ]),
        ),
      );
    }

    return [
      Row(children: [
        Expanded(child: Text('$doneThisWeek job${doneThisWeek == 1 ? '' : 's'} done this week 💪', style: const TextStyle(fontWeight: FontWeight.w800))),
        TextButton.icon(onPressed: _addTemplates, icon: const Icon(Icons.playlist_add, size: 18), label: const Text('Quick add')),
      ]),
      if (_tasks.isEmpty)
        const EmptyState(emoji: '🏠', title: 'Set up your home routine', subtitle: 'Tap "Quick add" for common jobs like laundry, cleaning and generator service.'),
      if (due.isNotEmpty) ...[const SectionTitle('Due now'), ...due.map(tile)],
      if (later.isNotEmpty) ...[
        for (final a in _areas)
          if (later.any((t) => t['area'] == a.$1)) ...[
            SectionTitle(a.$2),
            ...later.where((t) => t['area'] == a.$1).map(tile),
          ],
      ],
    ];
  }

  List<Widget> _billsView() {
    final month = DateTime.now();
    final monthTotal = _bills.where((b) {
      final d = DateTime.parse('${b['next_due']}');
      return d.year == month.year && d.month == month.month;
    }).fold<num>(0, (s, b) => s + ((b['amount'] as num?) ?? 0));
    return [
      if (_bills.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Due this month: ${naira(monthTotal)}', style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
      if (_bills.isEmpty) const EmptyState(emoji: '🧾', title: 'Never miss a bill', subtitle: 'Add electricity, rent, DSTV, internet or school fees and get reminded before they\'re due.'),
      ..._bills.map((b) {
        final d = DateTime.parse('${b['next_due']}');
        final overdue = d.isBefore(DateTime(month.year, month.month, month.day));
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: WhiteCard(
            onTap: () => _editBill(b),
            child: Row(children: [
              Text('${b['emoji']}', style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${b['name']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text('${b['amount'] == null ? '' : '${naira(b['amount'] as num)} · '}${dueLabel(d)} · ${b['repeat']}',
                      style: TextStyle(fontSize: 12, color: overdue ? Colors.red.shade400 : AppColors.muted, fontWeight: overdue ? FontWeight.w800 : null)),
                ]),
              ),
              FilledButton.tonal(onPressed: () => _payBill(b), child: const Text('Pay')),
            ]),
          ),
        );
      }),
    ];
  }

  List<Widget> _utilView() {
    String summary(String kind, String label, String emoji) {
      final logs = _utils.where((u) => u['kind'] == kind).toList();
      if (logs.isEmpty) return '$emoji $label: nothing logged yet';
      final last = DateTime.parse('${logs.first['logged_on']}');
      final days = DateTime.now().difference(last).inDays;
      var avg = '';
      if (logs.length >= 2) {
        final gaps = <int>[];
        for (var i = 0; i < logs.length - 1 && i < 6; i++) {
          gaps.add(DateTime.parse('${logs[i]['logged_on']}').difference(DateTime.parse('${logs[i + 1]['logged_on']}')).inDays);
        }
        final a = gaps.reduce((x, y) => x + y) / gaps.length;
        avg = ' · usually lasts ~${a.round()} days';
      }
      final m = DateTime.now();
      final monthSpend = logs.where((u) {
        final d = DateTime.parse('${u['logged_on']}');
        return d.month == m.month && d.year == m.year;
      }).fold<num>(0, (s, u) => s + ((u['amount'] as num?) ?? 0));
      return '$emoji $label: last top-up $days day${days == 1 ? '' : 's'} ago$avg · ${naira(monthSpend)} this month';
    }

    return [
      WhiteCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final s in [
            summary('electricity', 'Electricity', '💡'),
            summary('gas', 'Cooking gas', '🔥'),
            summary('fuel', 'Generator fuel', '⛽'),
            summary('water', 'Water', '💧'),
          ])
            Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Text(s, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      ),
      const SectionTitle('History'),
      if (_utils.isEmpty) const Text('Log each time you buy units, refill gas or buy fuel to see how long they last.', style: TextStyle(color: AppColors.muted)),
      ..._utils.take(40).map((u) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(const {'electricity': '💡', 'gas': '🔥', 'fuel': '⛽', 'water': '💧'}[u['kind']] ?? '🧾', style: const TextStyle(fontSize: 22)),
            title: Text('${u['units'] != null ? '${u['units']} ' : ''}${u['kind']}${u['amount'] != null ? ' · ${naira(u['amount'] as num)}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${shortDate(DateTime.parse('${u['logged_on']}'))}${u['note'] != null ? ' · ${u['note']}' : ''}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.muted),
              onPressed: () async {
                await Life.delete('utility_logs', '${u['id']}');
                _load();
              },
            ),
          )),
    ];
  }

  List<Widget> _suppliesView() {
    final low = _supplies.where((s) => s['low_at'] != null && (s['qty'] as num) <= (s['low_at'] as num)).toList();
    return [
      if (low.isNotEmpty)
        WhiteCard(
          color: const Color(0xFFFFF5E6),
          child: Row(children: [
            Expanded(child: Text('📉 Running low: ${low.map((s) => s['name']).join(', ')}', style: const TextStyle(fontWeight: FontWeight.w800))),
            TextButton(
              onPressed: () async {
                for (final s in low) {
                  await FamilyService.addItem('${s['name']}', null, s['place'] == 'baby' ? 'baby' : 'household');
                }
                if (mounted) toast(context, 'Added ${low.length} item${low.length == 1 ? '' : 's'} to the shopping list');
              },
              child: const Text('Restock'),
            ),
          ]),
        ),
      if (_supplies.isEmpty)
        const EmptyState(emoji: '🧴', title: 'Track household supplies', subtitle: 'Detergent, tissue, diapers, soap... Get a nudge to restock before they run out.'),
      const SizedBox(height: 6),
      ..._supplies.map((s) {
        final isLow = s['low_at'] != null && (s['qty'] as num) <= (s['low_at'] as num);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: WhiteCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            onTap: () => _editSupply(s),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s['name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${s['place']}${isLow ? ' · running low' : ''}',
                      style: TextStyle(fontSize: 12, color: isLow ? Colors.orange.shade700 : AppColors.muted)),
                ]),
              ),
              IconButton(onPressed: () => _changeQty(s, -1), icon: const Icon(Icons.remove_circle_outline)),
              Text('${s['qty'] is num && (s['qty'] as num) == (s['qty'] as num).roundToDouble() ? (s['qty'] as num).toInt() : s['qty']} ${s['unit'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
              IconButton(onPressed: () => _changeQty(s, 1), icon: const Icon(Icons.add_circle_outline)),
            ]),
          ),
        );
      }),
    ];
  }

  List<Widget> _appliancesView() => [
        if (_appliances.isEmpty)
          const EmptyState(emoji: '🔌', title: 'Appliance records', subtitle: 'Keep warranty dates, service history and repairer contacts in one place.'),
        ..._appliances.map((a) {
          DateTime? nextService;
          if (a['last_service'] != null && a['service_every_months'] != null) {
            final l = DateTime.parse('${a['last_service']}');
            nextService = DateTime(l.year, l.month + (a['service_every_months'] as int), l.day);
          }
          final warranty = a['warranty_until'] == null ? null : DateTime.parse('${a['warranty_until']}');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: WhiteCard(
              onTap: () => _editAppliance(a),
              child: Row(children: [
                Text('${a['emoji']}', style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${a['name']}${a['brand'] != null ? ' · ${a['brand']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    if (nextService != null)
                      Text('Next service: ${dueLabel(nextService)}',
                          style: TextStyle(fontSize: 12, color: nextService.isBefore(DateTime.now()) ? Colors.red.shade400 : AppColors.muted)),
                    if (warranty != null)
                      Text(warranty.isAfter(DateTime.now()) ? 'Under warranty until ${shortDate(warranty)}' : 'Warranty ended ${shortDate(warranty)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                if (nextService != null)
                  TextButton(
                    onPressed: () async {
                      await Life.update('appliances', '${a['id']}', {'last_service': Life.d(DateTime.now())});
                      _load();
                    },
                    child: const Text('Serviced'),
                  ),
              ]),
            ),
          );
        }),
      ];
}
