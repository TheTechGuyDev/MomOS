import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/life_service.dart';
import '../core/profile_service.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../widgets/form_sheet.dart';
import '../widgets/ui.dart';
import 'journal_screen.dart';

const closetCategories = <(String, String)>[
  ('top', '👚 Tops'),
  ('bottom', '👖 Bottoms'),
  ('dress', '👗 Dresses'),
  ('native', '🧣 Native / Ankara'),
  ('outerwear', '🧥 Jackets'),
  ('shoes', '👠 Shoes'),
  ('bag', '👜 Bags'),
  ('accessory', '💍 Accessories'),
  ('scarf', '🧕 Scarves & gele'),
];
const occasions = <(String, String)>[
  ('casual', 'Casual'),
  ('work', 'Work'),
  ('church', 'Church / Mosque'),
  ('party', 'Party / Owambe'),
  ('wedding', 'Wedding'),
  ('outing', 'Outing'),
  ('home', 'At home'),
];

class ClosetScreen extends StatefulWidget {
  const ClosetScreen({super.key});
  @override
  State<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  List<Rec> _items = [], _outfits = [], _wish = [];
  bool _loading = true;
  String _tab = 'wardrobe';
  String _cat = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final uid = AppSession.uid;
      final r = await Future.wait([
        Life.list('closet_items', eq: {'user_id': uid}, order: 'created_at', ascending: false),
        Life.list('outfits', eq: {'user_id': uid}, order: 'created_at', ascending: false),
        Life.list('closet_wishlist', eq: {'user_id': uid}, order: 'priority'),
      ]);
      if (mounted) {
        setState(() {
          _items = r[0];
          _outfits = r[1];
          _wish = r[2];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editItem([Rec? it]) async {
    final v = await showFormSheet(context, title: it == null ? 'Add to wardrobe' : 'Edit item', fields: [
      const FieldSpec('photo', 'Take or add a photo', FieldType.photo),
      const FieldSpec('name', 'Name', FieldType.text, required: true, hint: 'e.g. Blue ankara gown'),
      FieldSpec('category', 'Type', FieldType.choice, options: closetCategories),
      const FieldSpec('color', 'Main colour', FieldType.text, hint: 'e.g. Navy blue'),
      FieldSpec('occasions', 'Good for', FieldType.multi, options: occasions),
    ], initial: {
      'name': it?['name'],
      'category': it?['category'] ?? 'top',
      'color': it?['color'],
      'occasions': it?['occasions'] ?? <String>[],
    });
    if (v == null) return;
    String? path = it?['photo_path'] as String?;
    final ph = v['photo'];
    if (ph is (Uint8List, String)) path = await Life.uploadPrivate(ph.$1, ph.$2, 'closet');
    final data = {'name': v['name'], 'category': v['category'], 'color': v['color'], 'occasions': v['occasions'] ?? [], 'photo_path': path};
    it == null ? await Life.insert('closet_items', data, family: false) : await Life.update('closet_items', '${it['id']}', data);
    _load();
  }

  Future<void> _newOutfit({String? occasion, List<String> preset = const [], String? name}) async {
    final picked = <String>{...preset};
    final nameC = TextEditingController(text: name ?? '');
    String occ = occasion ?? 'casual';
    DateTime? when;
    final ok = await showAppSheet<bool>(context, 'Create an outfit', (ctx, setS) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(controller: nameC, decoration: const InputDecoration(hintText: 'Outfit name (e.g. Sunday service look)')),
        const SizedBox(height: 10),
        ChipChoices<String>(options: occasions, value: occ, onChanged: (v) => setS(() => occ = v)),
        const SizedBox(height: 10),
        DateTimeButton(value: when, dateOnly: true, allowClear: true, emptyLabel: 'Plan it for a day (optional)', onChanged: (v) => setS(() => when = v)),
        const SizedBox(height: 10),
        const Text('Pick the pieces', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        SizedBox(
          height: 260,
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: _items.map((it) {
              final sel = picked.contains('${it['id']}');
              return GestureDetector(
                onTap: () => setS(() => sel ? picked.remove('${it['id']}') : picked.add('${it['id']}')),
                child: Stack(fit: StackFit.expand, children: [
                  _ItemThumb(it),
                  if (sel) Container(decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(14))),
                  if (sel) const Center(child: Icon(Icons.check_circle, color: Colors.white, size: 32)),
                ]),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            if (picked.isEmpty) return;
            await Life.insert('outfits', {
              'name': nameC.text.trim().isEmpty ? 'My outfit' : nameC.text.trim(),
              'item_ids': picked.toList(),
              'occasion': occ,
              'planned_for': when == null ? null : Life.d(when!),
            }, family: false, xp: true);
            if (ctx.mounted) Navigator.pop(ctx, true);
          },
          child: const Text('Save outfit'),
        ),
      ]);
    });
    if (ok == true) _load();
  }

  Future<void> _suggest() async {
    if (_items.length < 3) {
      toast(context, 'Add at least 3 items to your wardrobe first.');
      return;
    }
    final occ = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: occasions.map((o) => ListTile(title: Text(o.$2), onTap: () => Navigator.pop(ctx, o.$1))).toList()),
      ),
    );
    if (occ == null || !mounted) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final r = await supa.functions.invoke('assistant', body: {
        'mode': 'outfit',
        'occasion': occ,
        'items': _items.map((i) => {'id': i['id'], 'name': i['name'], 'category': i['category'], 'color': i['color'], 'occasions': i['occasions']}).toList(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      final d = r.data is String ? jsonDecode(r.data as String) : r.data;
      final ids = List<String>.from((d['item_ids'] ?? []) as List).where((id) => _items.any((i) => i['id'] == id)).toList();
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${d['name'] ?? 'Outfit idea'} ✨'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${d['why'] ?? ''}'),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: ids.map((id) => SizedBox(width: 70, height: 70, child: _ItemThumb(_items.firstWhere((i) => i['id'] == id)))).toList()),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _newOutfit(occasion: occ, preset: ids, name: '${d['name'] ?? ''}');
              },
              child: const Text('Save outfit'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        Navigator.pop(context);
        toast(context, 'Could not get a suggestion right now.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MyCloset 👗')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (_tab == 'wardrobe') return _editItem();
          if (_tab == 'outfits') return _newOutfit();
          final v = await showFormSheet(context, title: 'Add to wishlist', fields: [
            const FieldSpec('name', 'Item', FieldType.text, required: true),
            const FieldSpec('price', 'Price', FieldType.money),
            const FieldSpec('link', 'Link (optional)', FieldType.text),
            const FieldSpec('priority', 'Priority', FieldType.choice, options: [('1', 'Must have'), ('2', 'Nice to have'), ('3', 'Someday')]),
          ], initial: {'priority': '2'});
          if (v == null) return;
          await Life.insert('closet_wishlist', {'name': v['name'], 'price': v['price'], 'link': v['link'], 'priority': int.parse('${v['priority']}')}, family: false);
          _load();
        },
        icon: const Icon(Icons.add),
        label: Text(_tab == 'wardrobe' ? 'Add item' : (_tab == 'outfits' ? 'New outfit' : 'Add wish')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 100), children: [
              ChipChoices<String>(
                options: const [('wardrobe', 'Wardrobe'), ('outfits', 'Outfits'), ('wishlist', 'Wishlist')],
                value: _tab,
                onChanged: (v) => setState(() => _tab = v),
              ),
              const SizedBox(height: 10),
              ...switch (_tab) {
                'outfits' => _outfitsView(),
                'wishlist' => _wishView(),
                _ => _wardrobeView(),
              },
            ]),
    );
  }

  List<Widget> _wardrobeView() {
    final shown = _cat == 'all' ? _items : _items.where((i) => i['category'] == _cat).toList();
    return [
      WhiteCard(
        color: AppColors.primary.withValues(alpha: 0.08),
        onTap: _suggest,
        child: const Row(children: [
          Text('✨', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Expanded(child: Text('What should I wear? Get an outfit idea from your own wardrobe', style: TextStyle(fontWeight: FontWeight.w800))),
          Icon(Icons.chevron_right),
        ]),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final c in [('all', 'All'), ...closetCategories])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(label: Text(c.$2), selected: _cat == c.$1, onSelected: (_) => setState(() => _cat = c.$1)),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      if (shown.isEmpty) const EmptyState(emoji: '👗', title: 'Build your digital wardrobe', subtitle: 'Snap your clothes once, then plan outfits in seconds.'),
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
        children: shown
            .map((it) => GestureDetector(
                  onTap: () => _itemMenu(it),
                  child: Column(children: [
                    AspectRatio(aspectRatio: 1, child: _ItemThumb(it)),
                    const SizedBox(height: 4),
                    Text('${it['favorite'] == true ? '❤️ ' : ''}${it['name']}',
                        maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ]),
                ))
            .toList(),
      ),
    ];
  }

  Future<void> _itemMenu(Rec it) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.checkroom),
            title: const Text('I wore it today'),
            subtitle: Text(it['last_worn'] == null ? 'Not worn yet' : 'Last worn ${shortDate(DateTime.parse('${it['last_worn']}'))}'),
            onTap: () => Navigator.pop(ctx, 'worn'),
          ),
          ListTile(leading: Icon(it['favorite'] == true ? Icons.favorite : Icons.favorite_border), title: const Text('Favourite'), onTap: () => Navigator.pop(ctx, 'fav')),
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Edit'), onTap: () => Navigator.pop(ctx, 'edit')),
          ListTile(leading: Icon(Icons.delete_outline, color: Colors.red.shade400), title: const Text('Remove'), onTap: () => Navigator.pop(ctx, 'del')),
        ]),
      ),
    );
    switch (a) {
      case 'worn':
        await Life.update('closet_items', '${it['id']}', {'last_worn': Life.d(DateTime.now())});
      case 'fav':
        await Life.update('closet_items', '${it['id']}', {'favorite': !(it['favorite'] == true)});
      case 'edit':
        await _editItem(it);
      case 'del':
        if (mounted && await confirmDelete(context, 'Remove ${it['name']}?')) await Life.delete('closet_items', '${it['id']}');
    }
    _load();
  }

  List<Widget> _outfitsView() => [
        if (_outfits.isEmpty) const EmptyState(emoji: '✨', title: 'No outfits yet', subtitle: 'Combine pieces from your wardrobe and plan what to wear for events.'),
        ..._outfits.map((o) {
          final ids = List<String>.from((o['item_ids'] ?? []) as List);
          final pieces = _items.where((i) => ids.contains(i['id'])).toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: WhiteCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${o['name']}', style: const TextStyle(fontWeight: FontWeight.w900))),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                    onPressed: () async {
                      await Life.delete('outfits', '${o['id']}');
                      _load();
                    },
                  ),
                ]),
                Text(
                  '${occasions.firstWhere((x) => x.$1 == o['occasion'], orElse: () => ('', '')).$2}${o['planned_for'] != null ? ' · ${dueLabel(DateTime.parse('${o['planned_for']}'))}' : ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: pieces.map((p) => Padding(padding: const EdgeInsets.only(right: 6), child: SizedBox(width: 80, child: _ItemThumb(p)))).toList(),
                  ),
                ),
              ]),
            ),
          );
        }),
      ];

  List<Widget> _wishView() => [
        if (_wish.isEmpty) const EmptyState(emoji: '🛍️', title: 'Your wishlist', subtitle: 'Save clothes you want to buy, with prices. Link it to a savings goal in MyPocket.'),
        ..._wish.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: WhiteCard(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
                child: Row(children: [
                  Checkbox(
                    value: w['bought'] == true,
                    onChanged: (v) async {
                      await Life.update('closet_wishlist', '${w['id']}', {'bought': v ?? false});
                      _load();
                    },
                  ),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${w['name']}',
                          style: TextStyle(fontWeight: FontWeight.w800, decoration: w['bought'] == true ? TextDecoration.lineThrough : null)),
                      Text('${const {1: 'Must have', 2: 'Nice to have', 3: 'Someday'}[w['priority']]}${w['price'] != null ? ' · ${naira(w['price'] as num)}' : ''}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ]),
                  ),
                  if (w['link'] != null)
                    IconButton(
                      icon: const Icon(Icons.open_in_new, size: 18),
                      onPressed: () => launchUrl(Uri.parse('${w['link']}'.startsWith('http') ? '${w['link']}' : 'https://${w['link']}'), mode: LaunchMode.externalApplication),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                    onPressed: () async {
                      await Life.delete('closet_wishlist', '${w['id']}');
                      _load();
                    },
                  ),
                ]),
              ),
            )),
      ];
}

class _ItemThumb extends StatelessWidget {
  final Rec item;
  const _ItemThumb(this.item);
  @override
  Widget build(BuildContext context) {
    final p = item['photo_path'] as String?;
    if (p != null) {
      return LayoutBuilder(builder: (c, box) => PrivatePhoto(p, size: box.maxWidth));
    }
    return Container(
      decoration: BoxDecoration(color: AppColors.sky.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: Text(closetCategories.firstWhere((c) => c.$1 == item['category'], orElse: () => closetCategories.first).$2.split(' ').first,
          style: const TextStyle(fontSize: 28)),
    );
  }
}
