import 'package:material_ui/material_ui.dart';

import '../core/profile_service.dart';
import '../core/theme.dart';
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
      HomeTab(profile: widget.profile),
      const KidsTab(),
      const MemoryTab(),
      const WellnessTab(),
      const _ComingSoon(emoji: '🎓', title: 'Learn', phase: 7),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
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

class _ComingSoon extends StatelessWidget {
  final String emoji, title;
  final int phase;
  const _ComingSoon({required this.emoji, required this.title, required this.phase});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          Text('Coming in Phase $phase', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}
