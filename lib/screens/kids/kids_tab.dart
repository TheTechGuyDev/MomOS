import 'package:material_ui/material_ui.dart';

import '../../core/kids_service.dart';
import '../../core/theme.dart';
import '../../core/time_utils.dart';
import 'growth_view.dart';
import 'log_sheets.dart';
import 'tasks_view.dart';
import 'today_view.dart';
import 'vaccines_view.dart';

class KidsTab extends StatefulWidget {
  const KidsTab({super.key});
  @override
  State<KidsTab> createState() => _KidsTabState();
}

class _KidsTabState extends State<KidsTab> {
  List<Child> _children = [];
  String? _selectedId;
  String _view = 'today';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await KidsService.children();
      if (!mounted) return;
      setState(() {
        _children = c;
        if (_selectedId == null || !c.any((x) => x.id == _selectedId)) {
          // Start on the youngest child, who needs the most tracking
          _selectedId = c.isEmpty ? null : c.last.id;
          if (c.isNotEmpty) _view = c.last.isBaby ? 'today' : 'school';
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Child? get _selected => _children.where((c) => c.id == _selectedId).firstOrNull;

  Future<void> _childMenu(Child c) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text('Edit ${c.name}'), onTap: () => Navigator.pop(ctx, 'edit')),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
            title: Text('Remove ${c.name} and all her records', style: TextStyle(color: Colors.red.shade400)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') {
      if (await showChildSheet(context, existing: c) == true) _load();
    } else if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Remove ${c.name}?'),
          content: const Text('All feeds, sleeps, growth, vaccines and tasks for this child will be deleted. This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (ok == true) {
        await KidsService.deleteChild(c.id);
        _selectedId = null;
        _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;

    if (_children.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('👧👶', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text('Add your children', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text('Track feeds, sleep, diapers, growth, vaccines and school tasks.',
                textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () async {
                if (await showChildSheet(context) == true) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add a child'),
            ),
          ]),
        ),
      );
    }

    final c = _selected!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Row(children: [
            Text('Kids', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const Spacer(),
            IconButton.filledTonal(
              tooltip: 'Add a child',
              onPressed: () async {
                if (await showChildSheet(context) == true) _load();
              },
              icon: const Icon(Icons.person_add_alt_1),
            ),
          ]),
        ),
        SizedBox(
          height: 86,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            children: _children.map((k) {
              final sel = k.id == c.id;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedId = k.id;
                    _view = k.isBaby ? 'today' : 'school';
                  }),
                  onLongPress: () => _childMenu(k),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(children: [
                      Text(k.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(k.name,
                              style: TextStyle(fontWeight: FontWeight.w900, color: sel ? Colors.white : AppColors.ink)),
                          Text(ageText(k.birthDate),
                              style: TextStyle(fontSize: 12, color: sel ? Colors.white70 : AppColors.muted)),
                        ],
                      ),
                    ]),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'today', label: Text('Today')),
                ButtonSegment(value: 'school', label: Text('School')),
                ButtonSegment(value: 'growth', label: Text('Growth')),
                ButtonSegment(value: 'vaccines', label: Text('Vaccines')),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
        ),
        Expanded(
          child: switch (_view) {
            'school' => TasksView(key: ValueKey('s${c.id}'), child: c),
            'growth' => GrowthView(key: ValueKey('g${c.id}'), child: c),
            'vaccines' => VaccinesView(key: ValueKey('v${c.id}'), child: c),
            _ => TodayView(key: ValueKey('t${c.id}'), child: c),
          },
        ),
      ],
    );
  }
}
