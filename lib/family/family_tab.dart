import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/levels.dart';
import '../core/life_service.dart';
import '../core/profile_service.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../household/home_manager_screen.dart';
import '../screens/family/family_screen.dart';
import '../screens/kids/kids_tab.dart';
import '../widgets/form_sheet.dart';
import '../widgets/ui.dart';
import 'school_view.dart';
import 'shopping_view.dart';

class FamilyTab extends StatefulWidget {
  const FamilyTab({super.key});
  @override
  State<FamilyTab> createState() => _FamilyTabState();
}

class _FamilyTabState extends State<FamilyTab> {
  String _view = 'home';
  List<Profile> _members = [];
  final _cal = GlobalKey<FamilyCalendarViewState>();
  final _chores = GlobalKey<ChoresViewState>();

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
    const views = [
      ('home', '🏡 Overview'),
      ('kids', '👧 Kids'),
      ('school', '🎒 School'),
      ('calendar', '📅 Calendar'),
      ('chores', '🧺 Chores'),
      ('shopping', '🛒 Shopping'),
    ];
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: switch (_view) {
        'calendar' => FloatingActionButton(
            onPressed: () async {
              if (await showEventSheet(context) == true) _cal.currentState?.load();
            },
            child: const Icon(Icons.add)),
        'chores' => FloatingActionButton(
            onPressed: () async {
              if (await showChoreSheet(context, _members) == true) _chores.currentState?.load();
            },
            child: const Icon(Icons.add)),
        _ => null,
      },
      body: Column(children: [
        const TabHeader(title: 'Family', subtitle: 'Shared between you and your partner'),
        SizedBox(
          height: 46,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(20, 4, 20, 4), children: [
            for (final (k, l) in views)
              Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(label: Text(l), selected: _view == k, onSelected: (_) => setState(() => _view = k))),
          ]),
        ),
        Expanded(
          child: IndexedStack(index: views.indexWhere((v) => v.$1 == _view), children: [
            _Overview(members: _members, onGo: (v) => setState(() => _view = v)),
            const KidsTab(),
            const SchoolView(),
            FamilyCalendarView(key: _cal),
            ChoresView(key: _chores, members: _members),
            const ShoppingView(),
          ]),
        ),
      ]),
    );
  }
}

class _Overview extends StatefulWidget {
  final List<Profile> members;
  final ValueChanged<String> onGo;
  const _Overview({required this.members, required this.onGo});
  @override
  State<_Overview> createState() => _OverviewState();
}

class _OverviewState extends State<_Overview> {
  List<Rec> _posts = [];
  Family? _family;
  Map<String, dynamic> _share = {};
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = supa
        .channel('announcements-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'announcements', callback: (_) => _load())
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) supa.removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final me = await ProfileService.me();
      final r = await Future.wait([
        Life.list('announcements', order: 'created_at', ascending: false, limit: 30),
        ProfileService.myFamily(me?.familyId),
        supa.from('profiles').select('share_settings').eq('id', AppSession.uid).maybeSingle(),
      ]);
      if (mounted) {
        setState(() {
          _posts = r[0] as List<Rec>;
          _family = r[1] as Family?;
          _share = Map<String, dynamic>.from(((r[2] as Map?)?['share_settings'] ?? {}) as Map);
        });
      }
    } catch (_) {}
  }

  Future<void> _post() async {
    final v = await showFormSheet(context, title: 'Family announcement', saveLabel: 'Post', fields: [
      const FieldSpec('emoji', 'Icon', FieldType.emoji),
      const FieldSpec('message', 'Message', FieldType.multiline, required: true, hint: 'e.g. Visitors coming on Saturday, please clean the parlour 🙏'),
      const FieldSpec('pinned', 'Pin to the top', FieldType.toggle),
    ], initial: {'emoji': '📣'}, emojis: const ['📣', '❤️', '🎉', '⚠️', '🏠', '🛒', '👶', '🙏', '🍲', '🚗', '💡', '📅']);
    if (v == null) return;
    await Life.insert('announcements', {'emoji': v['emoji'], 'message': v['message'], 'pinned': v['pinned'] ?? false});
    _load();
  }

  Future<void> _setShare(String key, bool value) async {
    setState(() => _share[key] = value);
    await supa.from('profiles').update({'share_settings': _share}).eq('id', AppSession.uid);
  }

  @override
  Widget build(BuildContext context) {
    final pinned = _posts.where((p) => p['pinned'] == true).toList();
    final rest = _posts.where((p) => p['pinned'] != true).toList();
    String nameOf(dynamic id) => widget.members.where((m) => m.id == id).firstOrNull?.displayName ?? 'Family';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        if (_family != null)
          WhiteCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('🏡', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_family!.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    Text('Family code: ${_family!.inviteCode} (share it so your partner can join)', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _family!.inviteCode));
                    toast(context, 'Family code copied');
                  },
                ),
              ]),
              const Divider(height: 20),
              ...widget.members.map((m) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Text(m.avatar, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(m.id == AppSession.uid ? '${m.displayName} (you)' : m.displayName, style: const TextStyle(fontWeight: FontWeight.w700))),
                      Text('Lv ${LevelInfo.fromXp(m.xp).level}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ]),
                  )),
            ]),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: WhiteCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomeManagerScreen())),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🏠', style: TextStyle(fontSize: 26)),
                SizedBox(height: 6),
                Text('Home manager', style: TextStyle(fontWeight: FontWeight.w900)),
                Text('Cleaning, laundry, bills, utilities, supplies', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: WhiteCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomeManagerScreen(initialTab: 1))),
              child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('🧾', style: TextStyle(fontSize: 26)),
                SizedBox(height: 6),
                Text('Bills', style: TextStyle(fontWeight: FontWeight.w900)),
                Text('Electricity, rent, DSTV, school fees', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
          ),
        ]),
        SectionTitle('📣 Announcements', trailing: TextButton.icon(onPressed: _post, icon: const Icon(Icons.add, size: 18), label: const Text('Post'))),
        if (_posts.isEmpty) const Text('Share quick notes with the family, like "Visitors on Saturday" or "Gas is finished".', style: TextStyle(color: AppColors.muted)),
        ...[...pinned, ...rest].map((p) {
          final at = DateTime.parse('${p['created_at']}').toLocal();
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: WhiteCard(
              color: p['pinned'] == true ? AppColors.sun.withValues(alpha: 0.12) : null,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p['emoji']}', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p['message']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${nameOf(p['author'])} · ${timeAgo(at)}${p['pinned'] == true ? ' · 📌 pinned' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ]),
                ),
                if (p['author'] == AppSession.uid)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                    onPressed: () async {
                      await Life.delete('announcements', '${p['id']}');
                      _load();
                    },
                  ),
              ]),
            ),
          );
        }),
        const SectionTitle('🔒 What I share'),
        WhiteCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Always shared: family calendar, shopping list, chores, meal plan, kids, household jobs and announcements.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            const Text('Always private: journal, wellness, closet, me-time and your symptom checks.', style: TextStyle(fontSize: 12)),
            const Divider(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _share['expenses'] == true,
              onChanged: (v) => _setShare('expenses', v),
              title: const Text('Share household expenses by default', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Personal spending always stays private'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _share['goals'] == true,
              onChanged: (v) => _setShare('goals', v),
              title: const Text('Share new goals by default', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _share['bills'] != false,
              onChanged: (v) => _setShare('bills', v),
              title: const Text('Share new bills by default', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ]),
        ),
      ]),
    );
  }
}
