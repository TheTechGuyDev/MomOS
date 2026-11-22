import 'package:material_ui/material_ui.dart';

import '../ai/assistant_tab.dart';
import '../core/alarm_service.dart';
import '../core/offline.dart';
import '../core/profile_service.dart';
import '../core/theme.dart';
import '../family/family_tab.dart';
import '../kitchen/kitchen_tab.dart';
import '../planner/planner_tab.dart';
import 'home_tab.dart';

/// Home · Planner · Kitchen · Family · AI
class HomeShell extends StatefulWidget {
  final Profile profile;
  final VoidCallback onProfileChanged;
  const HomeShell({super.key, required this.profile, required this.onProfileChanged});

  /// Lets any screen switch tabs (e.g. "Ask AI" buttons).
  static void goTo(BuildContext context, int index) =>
      context.findAncestorStateOfType<_HomeShellState>()?.go(index);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _visited = <int>{0};

  void go(int i) => setState(() {
        _index = i;
        _visited.add(i);
      });

  @override
  void initState() {
    super.initState();
    Offline.start();
  }

  @override
  Widget build(BuildContext context) {
    // Tabs are built the first time they are opened, then kept alive.
    final pages = <Widget>[
      HomeTab(profile: widget.profile, onProfileChanged: widget.onProfileChanged, onNavigate: go),
      _visited.contains(1) ? const PlannerTab() : const SizedBox.shrink(),
      _visited.contains(2) ? const KitchenTab() : const SizedBox.shrink(),
      _visited.contains(3) ? const FamilyTab() : const SizedBox.shrink(),
      _visited.contains(4) ? const AssistantTab() : const SizedBox.shrink(),
    ];
    return Scaffold(
      body: AlarmWatcher(
        child: SafeArea(
          child: Column(children: [
            const _OfflineBar(),
            Expanded(child: IndexedStack(index: _index, children: pages)),
          ]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note), label: 'Planner'),
          NavigationDestination(icon: Icon(Icons.soup_kitchen_outlined), selectedIcon: Icon(Icons.soup_kitchen), label: 'Kitchen'),
          NavigationDestination(icon: Icon(Icons.family_restroom_outlined), selectedIcon: Icon(Icons.family_restroom), label: 'Family'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI'),
        ],
      ),
    );
  }
}

class _OfflineBar extends StatelessWidget {
  const _OfflineBar();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Offline.online,
      builder: (context, online, _) => ValueListenableBuilder<int>(
        valueListenable: Offline.pending,
        builder: (context, pending, _) {
          if (online && pending == 0) return const SizedBox.shrink();
          return Container(
            width: double.infinity,
            color: online ? AppColors.sky.withValues(alpha: 0.18) : const Color(0xFFFFF1E0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              online
                  ? 'Syncing $pending change${pending == 1 ? '' : 's'}…'
                  : '📴 Offline. Showing saved info; changes will sync when you\'re back online.',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          );
        },
      ),
    );
  }
}
