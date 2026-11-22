import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../core/family_service.dart';
import '../core/life_service.dart';
import '../core/profile_service.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../meals/dishes.dart';
import '../meals/meals_screen.dart';
import '../meals/meals_service.dart';
import '../family/shopping_view.dart';
import '../widgets/form_sheet.dart';
import '../widgets/ui.dart';

class KitchenTab extends StatefulWidget {
  const KitchenTab({super.key});
  @override
  State<KitchenTab> createState() => _KitchenTabState();
}

class _KitchenTabState extends State<KitchenTab> {
  String _view = 'meals';
  Rec? _prefs;
  final _pantryKey = GlobalKey<_PantryState>();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final r = await supa.from('food_prefs').select().maybeSingle();
      if (mounted) setState(() => _prefs = r);
    } catch (_) {}
  }

  Set<String> get _avoid => {
        ...List<String>.from((_prefs?['dislikes'] ?? []) as List),
        ...List<String>.from((_prefs?['allergies'] ?? []) as List),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _view == 'pantry'
          ? FloatingActionButton(onPressed: () => _pantryKey.currentState?.edit(), child: const Icon(Icons.add))
          : null,
      body: Column(children: [
        const TabHeader(title: 'Kitchen', subtitle: 'Meals, groceries, pantry and food budget'),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(20, 4, 20, 4), children: [
            for (final (k, l) in const [('meals', '🍲 Meal plan'), ('grocery', '🛒 Grocery list'), ('pantry', '🥫 Pantry'), ('cook', '👩🏾‍🍳 What can I cook?'), ('budget', '💰 Budget & tastes')])
              Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(l), selected: _view == k, onSelected: (_) => setState(() => _view = k))),
          ]),
        ),
        Expanded(
          child: IndexedStack(
            index: ['meals', 'grocery', 'pantry', 'cook', 'budget'].indexOf(_view),
            children: [
              MealsView(avoid: _avoid),
              const _Grocery(),
              _Pantry(key: _pantryKey),
              _Cook(prefs: _prefs),
              _Budget(prefs: _prefs, onSaved: _loadPrefs),
            ],
          ),
        ),
      ]),
    );
  }
}

// ---------------- Grocery list: generate from the meal plan + shared list ----------------

class _Grocery extends StatefulWidget {
  const _Grocery();
  @override
  State<_Grocery> createState() => _GroceryState();
}

class _GroceryState extends State<_Grocery> {
  int _version = 0;

  Future<void> _fromPlan() async {
    final plan = await MealsService.load(MealsService.weekStart(DateTime.now()));
    if (!mounted) return;
    if (plan == null) {
      toast(context, 'Make a meal plan first (Meal plan tab).');
      return;
    }
    final needs = MealsService.groceriesFor(plan);
    final pantry = (await Life.list('inventory_items')).where((i) => (i['qty'] as num) > 0).map((i) => '${i['name']}'.toLowerCase()).toList();
    bool have(String ing) => pantry.any((p) => p.length > 2 && ing.toLowerCase().contains(p));
    final items = needs.keys.toList()..sort();
    final picked = {for (final i in items) i: !have(i)};
    if (!mounted) return;
    final ok = await showAppSheet<bool>(context, 'Groceries for this week\'s meals', (ctx, setS) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Unticked items are already in your pantry.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 6),
        ...items.map((i) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: picked[i],
              onChanged: (v) => setS(() => picked[i] = v ?? false),
              title: Text(i),
              subtitle: needs[i]! > 1 ? Text('for ${needs[i]} meals') : null,
            )),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () async {
            final chosen = picked.entries.where((e) => e.value).map((e) => e.key).toList();
            for (final c in chosen) {
              await FamilyService.addItem(c, needs[c]! > 1 ? 'x${needs[c]}' : null, 'food');
            }
            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: Text('Add ${picked.values.where((v) => v).length} items to the list'),
        ),
      ]);
    });
    if (ok == true) setState(() => _version++);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: WhiteCard(
          color: AppColors.mint.withValues(alpha: 0.12),
          onTap: _fromPlan,
          child: const Row(children: [
            Text('🪄', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Expanded(child: Text('Make my grocery list from this week\'s meal plan', style: TextStyle(fontWeight: FontWeight.w800))),
            Icon(Icons.chevron_right),
          ]),
        ),
      ),
      Expanded(child: ShoppingView(key: ValueKey(_version))),
    ]);
  }
}

// ---------------- Pantry with expiry ----------------

class _Pantry extends StatefulWidget {
  const _Pantry({super.key});
  @override
  State<_Pantry> createState() => _PantryState();
}

class _PantryState extends State<_Pantry> {
  List<Rec> _items = [];
  bool _loading = true;
  String _place = 'all';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await Life.list('inventory_items', order: 'expires_on');
      if (mounted) {
        setState(() {
          _items = r.where((i) => ['kitchen', 'fridge', 'freezer'].contains(i['place'])).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> edit([Rec? s]) async {
    final v = await showFormSheet(context, title: s == null ? 'Add food to pantry' : 'Update ${s['name']}', fields: [
      const FieldSpec('name', 'Food item', FieldType.text, required: true, hint: 'e.g. Rice, tomatoes, chicken, eggs'),
      const FieldSpec('place', 'Where is it?', FieldType.choice, options: [('kitchen', '🥫 Cupboard'), ('fridge', '🧊 Fridge'), ('freezer', '❄️ Freezer')]),
      const FieldSpec('qty', 'Quantity', FieldType.number, required: true),
      const FieldSpec('unit', 'Unit', FieldType.text, hint: 'kg, pieces, crates, tins'),
      const FieldSpec('expires_on', 'Use by (optional)', FieldType.date),
      const FieldSpec('low_at', 'Restock when it gets to (optional)', FieldType.number),
      const FieldSpec('price', 'Price paid (optional)', FieldType.money),
    ], initial: {
      'name': s?['name'],
      'place': s?['place'] ?? 'kitchen',
      'qty': s?['qty'] ?? 1,
      'unit': s?['unit'],
      'expires_on': Life.parseDate(s?['expires_on']),
      'low_at': s?['low_at'],
      'price': s?['price'],
    });
    if (v == null) return;
    final data = {
      'name': v['name'],
      'place': v['place'],
      'qty': v['qty'],
      'unit': v['unit'],
      'expires_on': v['expires_on'] == null ? null : Life.d(v['expires_on'] as DateTime),
      'low_at': v['low_at'],
      'price': v['price'],
    };
    s == null ? await Life.insert('inventory_items', data) : await Life.update('inventory_items', '${s['id']}', data);
    load();
  }

  Future<void> _use(Rec s, num by) async {
    final q = ((s['qty'] as num) + by).clamp(0, 9999);
    await Life.update('inventory_items', '${s['id']}', {'qty': q});
    if (q == 0 && mounted) {
      final add = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${s['name']} is finished'),
          content: const Text('Add it to the shopping list?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      );
      if (add == true) await FamilyService.addItem('${s['name']}', null, 'food');
    }
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final shown = _place == 'all' ? _items : _items.where((i) => i['place'] == _place).toList();
    final expiring = _items.where((i) => i['expires_on'] != null && DateTime.parse('${i['expires_on']}').difference(today).inDays <= 3 && (i['qty'] as num) > 0).toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
        if (expiring.isNotEmpty)
          WhiteCard(
            color: const Color(0xFFFFF5E6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('⏳ Use these soon', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              ...expiring.map((i) {
                final d = DateTime.parse('${i['expires_on']}');
                final days = d.difference(today).inDays;
                return Text('• ${i['name']}: ${days < 0 ? 'expired ${-days}d ago' : (days == 0 ? 'today' : 'in $days day${days == 1 ? '' : 's'}')}',
                    style: TextStyle(color: days < 0 ? Colors.red.shade400 : null));
              }),
            ]),
          ),
        const SizedBox(height: 8),
        ChipChoices<String>(
          options: const [('all', 'All'), ('kitchen', '🥫 Cupboard'), ('fridge', '🧊 Fridge'), ('freezer', '❄️ Freezer')],
          value: _place,
          onChanged: (v) => setState(() => _place = v),
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          const EmptyState(emoji: '🥫', title: 'What\'s in your kitchen?', subtitle: 'Add foodstuff with use-by dates. You\'ll get reminders before things spoil, and meal ideas from what you have.'),
        ...shown.map((s) {
          final exp = s['expires_on'] == null ? null : DateTime.parse('${s['expires_on']}');
          final days = exp?.difference(today).inDays;
          final qty = s['qty'] as num;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: WhiteCard(
              padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
              onTap: () => edit(s),
              child: Row(children: [
                Text(const {'kitchen': '🥫', 'fridge': '🧊', 'freezer': '❄️'}[s['place']] ?? '🥫', style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${s['name']}', style: TextStyle(fontWeight: FontWeight.w800, color: qty == 0 ? AppColors.muted : AppColors.ink)),
                    if (days != null)
                      Text(days < 0 ? 'Expired' : 'Use by ${shortDate(exp!)}',
                          style: TextStyle(fontSize: 12, color: days <= 3 ? Colors.orange.shade800 : AppColors.muted)),
                  ]),
                ),
                IconButton(onPressed: () => _use(s, -1), icon: const Icon(Icons.remove_circle_outline)),
                Text('${qty == qty.roundToDouble() ? qty.toInt() : qty} ${s['unit'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w900)),
                IconButton(onPressed: () => _use(s, 1), icon: const Icon(Icons.add_circle_outline)),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ---------------- What can I cook? (AI + recipe matching) ----------------

class _Cook extends StatefulWidget {
  final Rec? prefs;
  const _Cook({required this.prefs});
  @override
  State<_Cook> createState() => _CookState();
}

class _CookState extends State<_Cook> {
  final _c = TextEditingController();
  bool _busy = false;
  List<Map<String, dynamic>> _ideas = [];
  List<Dish> _matches = [];

  Future<void> _fromPantry() async {
    final items = (await Life.list('inventory_items')).where((i) => ['kitchen', 'fridge', 'freezer'].contains(i['place']) && (i['qty'] as num) > 0);
    _c.text = items.map((i) => i['name']).join(', ');
    _ask();
  }

  Future<void> _ask() async {
    final have = _c.text.split(RegExp(r'[,\n]')).map((s) => s.trim().toLowerCase()).where((s) => s.length > 1).toList();
    if (have.isEmpty) return;
    // Recipes from the built-in library that use what she has
    final scored = dishes.map((d) {
      final hits = d.ingredients.where((i) => have.any((h) => i.toLowerCase().contains(h))).length;
      return (d, hits);
    }).where((x) => x.$2 > 0).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    setState(() {
      _matches = scored.take(5).map((x) => x.$1).toList();
      _busy = true;
      _ideas = [];
    });
    try {
      final r = await supa.functions.invoke('assistant', body: {
        'mode': 'cook',
        'ingredients': have,
        'dislikes': widget.prefs?['dislikes'] ?? [],
        'allergies': widget.prefs?['allergies'] ?? [],
      });
      final d = r.data is String ? jsonDecode(r.data as String) : r.data;
      if (d['ideas'] is List) _ideas = List<Map<String, dynamic>>.from((d['ideas'] as List).map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
      const Text('What do you have?', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      const SizedBox(height: 6),
      TextField(
        controller: _c,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(hintText: 'e.g. rice, tomatoes, chicken, eggs'),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: FilledButton.icon(onPressed: _busy ? null : _ask, icon: const Icon(Icons.auto_awesome), label: const Text('Suggest meals'))),
        const SizedBox(width: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
          onPressed: _busy ? null : _fromPantry,
          child: const Text('Use my pantry'),
        ),
      ]),
      if (_busy) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
      if (_ideas.isNotEmpty) ...[
        const SectionTitle('Ideas for you ✨'),
        ..._ideas.map((i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: WhiteCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i['name']}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  if (i['time'] != null) Text('⏱ ${i['time']}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  if (i['missing'] is List && (i['missing'] as List).isNotEmpty)
                    Text('You may also need: ${(i['missing'] as List).join(', ')}', style: TextStyle(fontSize: 12, color: Colors.orange.shade800)),
                  const SizedBox(height: 6),
                  ...List<String>.from((i['steps'] ?? []) as List).asMap().entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${e.key + 1}. ${e.value}'),
                      )),
                ]),
              ),
            )),
      ],
      if (_matches.isNotEmpty) ...[
        const SectionTitle('From your recipe book'),
        ..._matches.map((d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: WhiteCard(
                padding: const EdgeInsets.all(10),
                onTap: () => showDishSheet(context, d),
                child: Row(children: [
                  SizedBox(width: 56, height: 56, child: DishImage(d, radius: 12, emojiSize: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text('${d.minutes} min', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
              ),
            )),
      ],
    ]);
  }
}

// ---------------- Food budget and family tastes ----------------

class _Budget extends StatefulWidget {
  final Rec? prefs;
  final VoidCallback onSaved;
  const _Budget({required this.prefs, required this.onSaved});
  @override
  State<_Budget> createState() => _BudgetState();
}

class _BudgetState extends State<_Budget> {
  num _spent = 0;
  num _shopping = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = DateTime.now();
      final from = Life.d(DateTime(m.year, m.month, 1));
      final tx = await supa.from('transactions').select('amount').eq('kind', 'expense').eq('category', 'food').gte('on_date', from);
      final shop = await supa.from('shopping_items').select('price').eq('checked', true).gte('checked_at', DateTime(m.year, m.month, 1).toUtc().toIso8601String());
      if (mounted) {
        setState(() {
          _spent = tx.fold<num>(0, (s, r) => s + (r['amount'] as num));
          _shopping = shop.fold<num>(0, (s, r) => s + ((r['price'] as num?) ?? 0));
        });
      }
    } catch (_) {}
  }

  Future<void> _edit() async {
    final p = widget.prefs;
    List<String> split(dynamic v) => '${v ?? ''}'.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final v = await showFormSheet(context, title: 'Budget & family tastes', fields: [
      const FieldSpec('monthly_food_budget', 'Monthly food budget', FieldType.money),
      const FieldSpec('monthly_shopping_budget', 'Monthly shopping budget (all items)', FieldType.money),
      const FieldSpec('likes', 'Family favourites (comma separated)', FieldType.text, hint: 'jollof, plantain, moi moi'),
      const FieldSpec('dislikes', 'Foods to avoid (comma separated)', FieldType.text, hint: 'okra, ogbono'),
      const FieldSpec('allergies', 'Allergies (comma separated)', FieldType.text, hint: 'groundnut, shellfish'),
      const FieldSpec('notes', 'Notes', FieldType.multiline, hint: 'e.g. Big sister doesn\'t like pepper'),
    ], initial: {
      'monthly_food_budget': p?['monthly_food_budget'],
      'monthly_shopping_budget': p?['monthly_shopping_budget'],
      'likes': List<String>.from((p?['likes'] ?? []) as List).join(', '),
      'dislikes': List<String>.from((p?['dislikes'] ?? []) as List).join(', '),
      'allergies': List<String>.from((p?['allergies'] ?? []) as List).join(', '),
      'notes': p?['notes'],
    });
    if (v == null) return;
    await supa.from('food_prefs').upsert({
      'family_id': await AppSession.familyId(),
      'monthly_food_budget': v['monthly_food_budget'],
      'monthly_shopping_budget': v['monthly_shopping_budget'],
      'likes': split(v['likes']),
      'dislikes': split(v['dislikes']),
      'allergies': split(v['allergies']),
      'notes': v['notes'],
    });
    widget.onSaved();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prefs;
    final budget = p?['monthly_food_budget'] as num?;
    final used = _spent + _shopping;
    final pct = budget == null || budget == 0 ? null : (used / budget).toDouble();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
      WhiteCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Food spending this month', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(naira(used), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          Text('Food expenses ${naira(_spent)} + groceries ticked with prices ${naira(_shopping)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          if (pct != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct.clamp(0, 1),
                minHeight: 10,
                color: pct >= 1 ? Colors.red.shade400 : (pct >= 0.8 ? Colors.orange : AppColors.mint),
              ),
            ),
            const SizedBox(height: 4),
            Text(pct >= 1 ? 'Over budget by ${naira(used - budget!)}' : '${naira(budget! - used)} left of ${naira(budget)}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ] else
            TextButton(onPressed: _edit, child: const Text('Set a monthly food budget')),
        ]),
      ),
      const SizedBox(height: 12),
      WhiteCard(
        onTap: _edit,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Expanded(child: Text('Family food preferences', style: TextStyle(fontWeight: FontWeight.w900))),
            Icon(Icons.edit_outlined, size: 18),
          ]),
          const SizedBox(height: 6),
          Text('❤️ Likes: ${List<String>.from((p?['likes'] ?? []) as List).join(', ').ifEmpty('not set')}'),
          Text('🚫 Avoid: ${List<String>.from((p?['dislikes'] ?? []) as List).join(', ').ifEmpty('not set')}'),
          Text('⚠️ Allergies: ${List<String>.from((p?['allergies'] ?? []) as List).join(', ').ifEmpty('none')}'),
          if (p?['notes'] != null) Text('📝 ${p!['notes']}'),
          const SizedBox(height: 6),
          const Text('Meal plans and AI suggestions avoid the foods you list here.', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
    ]);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

