import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../core/profile_service.dart';
import '../core/theme.dart';

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
      const _ComingSoon(emoji: '👶', title: 'Kids', phase: 3),
      const _ComingSoon(emoji: '🧠', title: 'Memory', phase: 4),
      const _ComingSoon(emoji: '🌿', title: 'Wellness', phase: 5),
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

class HomeTab extends StatefulWidget {
  final Profile profile;
  const HomeTab({super.key, required this.profile});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final Future<Family?> _family = ProfileService.myFamily(widget.profile.familyId);

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = widget.profile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(p.avatar, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greeting, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                  Text(p.displayName, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: () => supa.auth.signOut(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Level 1', style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${p.xp} XP', style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('Streaks, badges and quests arrive in Phase 2',
                        style: t.bodySmall?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              const Text('🏆', style: TextStyle(fontSize: 44)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Family?>(
          future: _family,
          builder: (context, snap) {
            final f = snap.data;
            if (f == null) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const Text('🏡', style: TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        Text('Family code: ${f.inviteCode}', style: t.bodySmall?.copyWith(color: AppColors.muted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy code',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: f.inviteCode));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Family code copied')));
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ],
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
