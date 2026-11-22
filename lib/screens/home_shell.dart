import 'package:material_ui/material_ui.dart';

import '../core/profile_service.dart';
import '../core/alarm_service.dart';
import '../learn/learn_tab.dart';
import 'home_tab.dart';
import 'kids/kids_tab.dart';
import 'memory/memory_tab.dart';
import 'wellness/wellness_tab.dart';

class HomeShell extends StatefulWidget {
  final Profile profile;
  final VoidCallback onProfileChanged;
  const HomeShell({super.key, required this.profile, required this.onProfileChanged});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeTab(
        profile: widget.profile,
        onProfileChanged: widget.onProfileChanged,
        onNavigate: (i) => setState(() => _index = i),
      ),
      const KidsTab(),
      const MemoryTab(),
      const WellnessTab(),
      const LearnTab(),
    ];
    return Scaffold(
      body: AlarmWatcher(child: SafeArea(child: IndexedStack(index: _index, children: pages))),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.child_care_outlined), selectedIcon: Icon(Icons.child_care), label: 'Kids'),
          NavigationDestination(icon: Icon(Icons.psychology_outlined), selectedIcon: Icon(Icons.psychology), label: 'Memory'),
          NavigationDestination(icon: Icon(Icons.spa_outlined), selectedIcon: Icon(Icons.spa), label: 'Wellness'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school), label: 'Learn'),
        ],
      ),
    );
  }
}
