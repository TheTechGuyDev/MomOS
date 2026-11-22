import 'package:material_ui/material_ui.dart';

import '../core/life_service.dart';
import '../core/profile_service.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../widgets/form_sheet.dart';
import '../widgets/ui.dart';

const expenseCategories = <(String, String)>[
  ('food', '🥘 Food'),
  ('household', '🏠 Household'),
  ('children', '👧 Children'),
  ('transport', '🚕 Transport'),
  ('bills', '🧾 Bills'),
  ('health', '💊 Health'),
  ('personal', '💅 Personal'),
  ('clothing', '👗 Clothing'),
  ('giving', '🙏 Giving'),
  ('family', '👨‍👩‍👧 Family support'),
  ('business', '💼 Business'),
  ('other', '📦 Other'),
];
const incomeCategories = <(String, String)>[
  ('salary', '💼 Salary'),
  ('business', '🛍️ Business'),
  ('allowance', '💗 Allowance'),
  ('gift', '🎁 Gift'),
  ('other', '📦 Other'),
];

String catLabel(String c) =>
    [...expenseCategories, ...incomeCategories].firstWhere((x) => x.$1 == c, orElse: () => (c, c)).$2;

Future<bool?> showTransactionSheet(BuildContext context, {String kind = 'expense', Rec? existing}) async {
  final isIncome = (existing?['kind'] ?? kind) == 'income';
  final v = await showFormSheet(
    context,
    title: existing != null ? 'Edit' : (isIncome ? 'Add income' : 'Add expense'),
    fields: [
      const FieldSpec('amount', 'Amount', FieldType.money, required: true),
      FieldSpec('category', 'Category', FieldType.choice, options: isIncome ? incomeCategories : expenseCategories),
      const FieldSpec('note', 'Note (optional)', FieldType.text, hint: 'e.g. Tomatoes and pepper at the market'),
      const FieldSpec('on_date', 'Date', FieldType.date, required: true),
      if (!isIncome) const FieldSpec('shared', 'Household expense', FieldType.toggle, hint: 'Your partner can see it in shared household spending'),
    ],
    initial: {
      'category': existing?['category'] ?? (isIncome ? 'salary' : 'food'),
      'on_date': Life.parseDate(existing?['on_date']) ?? DateTime.now(),
      'shared': existing?['shared'] ?? false,
      'amount': existing?['amount'],
      'note': existing?['note'],
    },
  );
  if (v == null) return null;
  final data = {
    'kind': isIncome ? 'income' : 'expense',
    'amount': v['amount'],
    'category': v['category'],
    'note': v['note'],
    'on_date': Life.d(v['on_date'] as DateTime),
    'shared': v['shared'] ?? false,
  };
  try {
    if (existing != null) {
      await Life.update('transactions', '${existing['id']}', data);
    } else {
      await Life.insert('transactions', data, xp: true);
    }
    if (context.mounted) toast(context, isIncome ? 'Income saved' : 'Expense saved. +1 XP');
    return true;
  } catch (_) {
    if (context.mounted) toast(context, 'Could not save. Please try again.');
    return false;
  }
}

class PocketScreen extends StatefulWidget {
  const PocketScreen({super.key});
  @override
  State<PocketScreen> createState() => _PocketScreenState();
}

class _PocketScreenState extends State<PocketScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<Rec> _tx = [], _budgets = [], _savings = [], _bills = [];
  bool _loading = true;
  String _view = 'overview';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final from = Life.d(_month);
      final to = Life.d(DateTime(_month.year, _month.month + 1, 0));
      final uid = supa.auth.currentUser!.id;
      final rows = await supa.from('transactions').select().gte('on_date', from).lte('on_date', to).order('on_date', ascending: false);
      final r = await Future.wait([
        Life.list('budgets', eq: {'user_id': uid}),
        Life.list('savings_goals', eq: {'user_id': uid}, order: 'created_at'),
        Life.list('bills', order: 'next_due'),
      ]);
      if (!mounted) return;
      setState(() {
        _tx = rows.map<Rec>((e) => Map<String, dynamic>.from(e)).toList();
        _budgets = r[0];
        _savings = r[1];
        _bills = r[2];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  num _sum(Iterable<Rec> rows) => rows.fold<num>(0, (s, r) => s + (r['amount'] as num));

  Future<void> _editBudget([Rec? b]) async {
    final v = await showFormSheet(context, title: b == null ? 'Set a monthly budget' : 'Edit budget', fields: [
      FieldSpec('category', 'Category', FieldType.choice, options: expenseCategories),
      const FieldSpec('monthly_limit', 'Monthly limit', FieldType.money, required: true),
    ], initial: {'category': b?['category'] ?? 'food', 'monthly_limit': b?['monthly_limit']});
    if (v == null) return;
    await supa.from('budgets').upsert({'category': v['category'], 'monthly_limit': v['monthly_limit']}, onConflict: 'user_id,category');
    _load();
  }

  Future<void> _editSaving([Rec? s]) async {
    final v = await showFormSheet(context, title: s == null ? 'New savings goal' : 'Edit savings goal', fields: [
      const FieldSpec('emoji', 'Icon', FieldType.emoji),
      const FieldSpec('title', 'What are you saving for?', FieldType.text, required: true, hint: 'e.g. Laptop for data analysis'),
      const FieldSpec('target', 'Target amount', FieldType.money, required: true),
      const FieldSpec('deadline', 'By when? (optional)', FieldType.date),
    ], initial: {
      'emoji': s?['emoji'] ?? '🏦',
      'title': s?['title'],
      'target': s?['target'],
      'deadline': Life.parseDate(s?['deadline']),
    }, emojis: const ['🏦', '💻', '🏠', '🚗', '✈️', '🎓', '👶', '💍', '📱', '🛋️', '🎁', '💰']);
    if (v == null) return;
    final data = {'emoji': v['emoji'], 'title': v['title'], 'target': v['target'], 'deadline': v['deadline'] == null ? null : Life.d(v['deadline'] as DateTime)};
    s == null ? await Life.insert('savings_goals', data, family: false) : await Life.update('savings_goals', '${s['id']}', data);
    _load();
  }

  Future<void> _addToSaving(Rec s) async {
    final v = await showFormSheet(context, title: 'Add to ${s['title']}', fields: [
      const FieldSpec('amount', 'Amount saved', FieldType.money, required: true),
    ]);
    if (v == null) return;
    await Life.update('savings_goals', '${s['id']}', {'saved': (s['saved'] as num) + (v['amount'] as num)});
    if (mounted) toast(context, 'Well done! Every naira counts 💪');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final income = _sum(_tx.where((x) => x['kind'] == 'income'));
    final expenses = _tx.where((x) => x['kind'] == 'expense').toList();
    final spent = _sum(expenses);
    final byCat = <String, num>{};
    for (final e in expenses) {
      byCat['${e['category']}'] = (byCat['${e['category']}'] ?? 0) + (e['amount'] as num);
    }
    final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('MyPocket 💰')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final kind = await showModalBottomSheet<String>(
            context: context,
            showDragHandle: true,
            builder: (ctx) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(leading: const Text('💸', style: TextStyle(fontSize: 24)), title: const Text('Expense'), onTap: () => Navigator.pop(ctx, 'expense')),
                ListTile(leading: const Text('💵', style: TextStyle(fontSize: 24)), title: const Text('Income'), onTap: () => Navigator.pop(ctx, 'income')),
              ]),
            ),
          );
          if (kind != null && context.mounted && await showTransactionSheet(context, kind: kind) == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), children: [
                Row(children: [
                  IconButton(
                      onPressed: () {
                        _month = DateTime(_month.year, _month.month - 1);
                        _load();
                      },
                      icon: const Icon(Icons.chevron_left)),
                  Expanded(
                      child: Text('${months[_month.month - 1]} ${_month.year}',
                          textAlign: TextAlign.center, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                  IconButton(
                      onPressed: () {
                        _month = DateTime(_month.year, _month.month + 1);
                        _load();
                      },
                      icon: const Icon(Icons.chevron_right)),
                ]),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF2F8F75), AppColors.mint]),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Left this month', style: TextStyle(color: Colors.white70)),
                    Text(naira(income - spent), style: t.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: Text('In: ${naira(income)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                      Expanded(child: Text('Out: ${naira(spent)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                    ]),
                  ]),
                ),
                const SizedBox(height: 12),
                ChipChoices<String>(
                  options: const [('overview', 'Overview'), ('budgets', 'Budgets'), ('savings', 'Savings'), ('history', 'History')],
                  value: _view,
                  onChanged: (v) => setState(() => _view = v),
                ),
                const SizedBox(height: 6),
                ...switch (_view) {
                  'budgets' => _budgetsView(byCat),
                  'savings' => _savingsView(),
                  'history' => _historyView(),
                  _ => _overview(cats, spent),
                },
              ]),
            ),
    );
  }

  List<Widget> _overview(List<MapEntry<String, num>> cats, num spent) {
    final alerts = _budgets.where((b) {
      final used = cats.where((c) => c.key == b['category']).fold<num>(0, (s, c) => s + c.value);
      return used >= (b['monthly_limit'] as num) * 0.8;
    }).toList();
    final upcoming = _bills.where((b) => DateTime.parse('${b['next_due']}').isBefore(DateTime.now().add(const Duration(days: 7)))).toList();
    return [
      if (alerts.isNotEmpty)
        ...alerts.map((b) {
          final used = cats.where((c) => c.key == b['category']).fold<num>(0, (s, c) => s + c.value);
          final over = used > (b['monthly_limit'] as num);
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: WhiteCard(
              color: over ? const Color(0xFFFDECEC) : const Color(0xFFFFF5E6),
              padding: const EdgeInsets.all(12),
              child: Text(
                '${over ? '🚨' : '⚠️'} ${catLabel('${b['category']}')}: ${naira(used)} of ${naira(b['monthly_limit'] as num)} budget ${over ? '(over!)' : 'used'}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          );
        }),
      if (upcoming.isNotEmpty) ...[
        const SectionTitle('Bills due soon'),
        ...upcoming.map((b) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: WhiteCard(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Text('${b['emoji']}', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${b['name']}', style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text('${b['amount'] == null ? '' : naira(b['amount'] as num)} · ${dueLabel(DateTime.parse('${b['next_due']}'))}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ]),
              ),
            )),
      ],
      const SectionTitle('Where the money went'),
      if (cats.isEmpty) const Text('No expenses yet this month.', style: TextStyle(color: AppColors.muted)),
      ...cats.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(catLabel(c.key), style: const TextStyle(fontWeight: FontWeight.w800))),
                Text('${naira(c.value)} · ${(c.value / (spent == 0 ? 1 : spent) * 100).round()}%'),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: (c.value / (spent == 0 ? 1 : spent)).toDouble(), minHeight: 8),
              ),
            ]),
          )),
    ];
  }

  List<Widget> _budgetsView(Map<String, num> byCat) => [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => _editBudget(), icon: const Icon(Icons.add), label: const Text('Set a budget')),
        ),
        if (_budgets.isEmpty)
          const EmptyState(emoji: '📊', title: 'No budgets yet', subtitle: 'Set a monthly limit for food, children or personal spending and get alerts at 80%.'),
        ..._budgets.map((b) {
          final used = byCat['${b['category']}'] ?? 0;
          final limit = b['monthly_limit'] as num;
          final pct = (used / limit).clamp(0, 1.5);
          final color = pct >= 1 ? Colors.red.shade400 : (pct >= 0.8 ? Colors.orange : AppColors.mint);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: WhiteCard(
              onTap: () => _editBudget(b),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(catLabel('${b['category']}'), style: const TextStyle(fontWeight: FontWeight.w900))),
                  Text('${naira(used)} / ${naira(limit)}'),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: pct.toDouble().clamp(0, 1), minHeight: 10, color: color),
                ),
                const SizedBox(height: 4),
                Text(used > limit ? 'Over by ${naira(used - limit)}' : '${naira(limit - used)} left',
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w800)),
              ]),
            ),
          );
        }),
      ];

  List<Widget> _savingsView() => [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => _editSaving(), icon: const Icon(Icons.add), label: const Text('New savings goal')),
        ),
        if (_savings.isEmpty) const EmptyState(emoji: '🏦', title: 'Start a savings goal', subtitle: 'Small amounts add up. Track each step towards something you want.'),
        ..._savings.map((s) {
          final pct = ((s['saved'] as num) / (s['target'] as num)).clamp(0, 1).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: WhiteCard(
              onTap: () => _editSaving(s),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('${s['emoji']}', style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s['title']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text('${naira(s['saved'] as num)} of ${naira(s['target'] as num)}${s['deadline'] != null ? ' · by ${shortDate(DateTime.parse('${s['deadline']}'))}' : ''}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ]),
                  ),
                  FilledButton.tonal(onPressed: () => _addToSaving(s), child: const Text('+ Add')),
                ]),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: pct, minHeight: 10)),
                if (pct >= 1) const Text('🎉 Goal reached!', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.mint)),
              ]),
            ),
          );
        }),
      ];

  List<Widget> _historyView() => [
        if (_tx.isEmpty) const EmptyState(emoji: '🧾', title: 'Nothing yet this month', subtitle: 'Tap Add to record money in or out.'),
        ..._tx.map((x) {
          final inc = x['kind'] == 'income';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: WhiteCard(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              onTap: () async {
                if (await showTransactionSheet(context, existing: x) == true) _load();
              },
              child: Row(children: [
                Text(catLabel('${x['category']}').split(' ').first, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${x['note'] ?? catLabel('${x['category']}').substring(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${shortDate(DateTime.parse('${x['on_date']}'))}${x['shared'] == true ? ' · household' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                Text('${inc ? '+' : '−'}${naira(x['amount'] as num)}',
                    style: TextStyle(fontWeight: FontWeight.w900, color: inc ? AppColors.mint : AppColors.ink)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
                  onPressed: () async {
                    if (await confirmDelete(context, 'Delete this entry?')) {
                      await Life.delete('transactions', '${x['id']}');
                      _load();
                    }
                  },
                ),
              ]),
            ),
          );
        }),
      ];
}
