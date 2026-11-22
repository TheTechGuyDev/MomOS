import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/family_service.dart';
import '../core/profile_service.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../widgets/form_sheet.dart';
import '../widgets/ui.dart';

/// Shared, live shopping list with prices, budget, "buy again", history and monthly reports.
class ShoppingView extends StatefulWidget {
  const ShoppingView({super.key});
  @override
  State<ShoppingView> createState() => ShoppingViewState();
}

class ShoppingViewState extends State<ShoppingView> {
  final _name = TextEditingController();
  final _qty = TextEditingController();
  String _cat = 'food';
  String _mode = 'list';
  List<ShoppingItem> _items = [];
  List<ShoppingItem> _history = [];
  num? _budget;
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    load();
    _channel = supa
        .channel('shopping-live-${DateTime.now().microsecondsSinceEpoch}')
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
      final r = await Future.wait([
        FamilyService.shopping(),
        FamilyService.purchases(since: DateTime.now().subtract(const Duration(days: 90))),
      ]);
      num? budget;
      try {
        final p = await supa.from('food_prefs').select('monthly_shopping_budget').maybeSingle();
        budget = p?['monthly_shopping_budget'] as num?;
      } catch (_) {}
      if (mounted) {
        setState(() {
          _items = r[0];
          _history = r[1];
          _budget = budget;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add([String? name]) async {
    final n = name ?? _name.text;
    if (n.trim().isEmpty) return;
    final q = name == null ? _qty.text : '';
    _name.clear();
    _qty.clear();
    try {
      await FamilyService.addItem(n, q, _cat);
      load();
    } catch (_) {
      if (mounted) toast(context, 'Could not add. Please try again.');
    }
  }

  Future<void> _edit(ShoppingItem i) async {
    final v = await showFormSheet(context, title: i.name, fields: [
      const FieldSpec('name', 'Item', FieldType.text, required: true),
      const FieldSpec('qty', 'Quantity', FieldType.text),
      const FieldSpec('price', 'Price paid / expected', FieldType.money),
      const FieldSpec('store', 'Where (market or store)', FieldType.text, hint: 'e.g. Mile 12, Shoprite'),
    ], initial: {'name': i.name, 'qty': i.qty, 'price': i.price, 'store': i.store});
    if (v == null) return;
    await FamilyService.updateItem(i.id, name: v['name'] as String?, qty: v['qty'] as String?, price: v['price'] as num?, store: v['store'] as String?);
    load();
  }

  Future<void> _toggle(ShoppingItem i) async {
    await FamilyService.setChecked(i.id, !i.checked);
    load();
    if (!i.checked && i.price == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${i.name} in the basket'),
        action: SnackBarAction(label: 'Add price', onPressed: () => _edit(i)),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // Price memory: last price paid for an item with the same name
  num? _lastPrice(String name) =>
      _history.where((h) => h.name.toLowerCase() == name.toLowerCase() && h.price != null).firstOrNull?.price;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 40), children: [
        ChipChoices<String>(
          options: const [('list', '🛒 List'), ('history', '📊 History & report')],
          value: _mode,
          onChanged: (v) => setState(() => _mode = v),
        ),
        const SizedBox(height: 8),
        ...(_mode == 'list' ? _listView() : _historyView()),
      ]),
    );
  }

  List<Widget> _listView() {
    final open = _items.where((i) => !i.checked).toList();
    final got = _items.where((i) => i.checked).toList();
    final byCat = <String, List<ShoppingItem>>{};
    for (final i in open) {
      byCat.putIfAbsent(i.category, () => []).add(i);
    }
    final now = DateTime.now();
    final monthSpent = _history.where((h) => h.checkedAt != null && h.checkedAt!.month == now.month && h.checkedAt!.year == now.year).fold<num>(0, (s, h) => s + (h.price ?? 0));
    final estimate = open.fold<num>(0, (s, i) => s + (i.price ?? _lastPrice(i.name) ?? 0));

    // "Buy again": bought at least twice in 90 days, not already on the list
    final counts = <String, int>{};
    for (final h in _history) {
      counts[h.name.toLowerCase()] = (counts[h.name.toLowerCase()] ?? 0) + 1;
    }
    final onList = _items.map((i) => i.name.toLowerCase()).toSet();
    final again = counts.entries.where((e) => e.value >= 2 && !onList.contains(e.key)).toList()..sort((a, b) => b.value.compareTo(a.value));

    return [
      if (_budget != null || monthSpent > 0)
        WhiteCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('This month\'s shopping', style: TextStyle(fontWeight: FontWeight.w900))),
              Text(_budget == null ? naira(monthSpent) : '${naira(monthSpent)} / ${naira(_budget)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            if (_budget != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (monthSpent / _budget!).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  color: monthSpent > _budget! ? Colors.red.shade400 : (monthSpent > _budget! * 0.8 ? Colors.orange : AppColors.mint),
                ),
              ),
            ],
            if (estimate > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Estimated cost of what\'s left on the list: ${naira(estimate)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
          ]),
        ),
      const SizedBox(height: 10),
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
            Expanded(child: TextField(controller: _qty, onSubmitted: (_) => _add(), decoration: const InputDecoration(hintText: 'Qty'))),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
          ]),
          const SizedBox(height: 10),
          ChipChoices<String>(options: shoppingCategories, value: _cat, onChanged: (v) => setState(() => _cat = v)),
        ]),
      ),
      if (again.isNotEmpty) ...[
        const SectionTitle('🔁 Buy again?'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: again.take(8).map((e) {
            final name = _history.firstWhere((h) => h.name.toLowerCase() == e.key).name;
            return ActionChip(avatar: const Icon(Icons.add, size: 16), label: Text(name), onPressed: () => _add(name));
          }).toList(),
        ),
      ],
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
              if (mounted) toast(context, 'Saved to shopping history');
              load();
            },
            child: const Text('Done shopping'),
          ),
        ),
        ...got.map(_tile),
      ],
    ];
  }

  Widget _tile(ShoppingItem i) {
    final last = i.price == null ? _lastPrice(i.name) : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: WhiteCard(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
        onTap: () => _toggle(i),
        child: Row(children: [
          Checkbox(value: i.checked, shape: const CircleBorder(), onChanged: (_) => _toggle(i)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                i.qty == null ? i.name : '${i.name}  ·  ${i.qty}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  decoration: i.checked ? TextDecoration.lineThrough : null,
                  color: i.checked ? AppColors.muted : AppColors.ink,
                ),
              ),
              if (i.price != null || last != null || i.store != null)
                Text(
                  [
                    if (i.price != null) naira(i.price),
                    if (i.price == null && last != null) 'last time ${naira(last)}',
                    if (i.store != null) i.store!,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ]),
          ),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted), onPressed: () => _edit(i)),
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

  List<Widget> _historyView() {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final byMonth = <String, List<ShoppingItem>>{};
    for (final h in _history.where((h) => h.checkedAt != null)) {
      byMonth.putIfAbsent('${h.checkedAt!.year}-${h.checkedAt!.month}', () => []).add(h);
    }
    if (byMonth.isEmpty) {
      return [const EmptyState(emoji: '📊', title: 'No shopping history yet', subtitle: 'Tick items and tap "Done shopping". Add prices to see monthly reports.')];
    }
    final out = <Widget>[];
    for (final e in byMonth.entries) {
      final parts = e.key.split('-');
      final items = e.value;
      final total = items.fold<num>(0, (s, i) => s + (i.price ?? 0));
      final byCat = <String, num>{};
      for (final i in items) {
        byCat[i.category] = (byCat[i.category] ?? 0) + (i.price ?? 0);
      }
      final cats = byCat.entries.where((c) => c.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
      out.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: WhiteCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${months[int.parse(parts[1]) - 1]} ${parts[0]}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              Text(naira(total), style: const TextStyle(fontWeight: FontWeight.w900)),
            ]),
            Text('${items.length} items bought', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 8),
            ...cats.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(shoppingCategories.firstWhere((x) => x.$1 == c.key, orElse: () => (c.key, c.key)).$2)),
                      Text(naira(c.value)),
                    ]),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: total == 0 ? 0 : (c.value / total).toDouble(), minHeight: 6),
                    ),
                  ]),
                )),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('See items', style: TextStyle(fontWeight: FontWeight.w700)),
                children: items
                    .map((i) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(i.qty == null ? i.name : '${i.name} · ${i.qty}'),
                          subtitle: Text('${shortDate(i.checkedAt!)}${i.store != null ? ' · ${i.store}' : ''}'),
                          trailing: Text(i.price == null ? '—' : naira(i.price)),
                        ))
                    .toList(),
              ),
            ),
          ]),
        ),
      ));
    }
    return out;
  }
}
