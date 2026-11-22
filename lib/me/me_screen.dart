import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../learn/learn_tab.dart';
import '../screens/wellness/wellness_tab.dart';
import '../widgets/ui.dart';
import 'closet_screen.dart';
import 'journal_screen.dart';
import 'metime_screen.dart';
import 'pocket_screen.dart';

/// "Me" space: everything that is just for her.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final items = <(String, String, String, Color, Widget Function())>[
      ('🌿', 'Wellness', 'Mood, water, sleep, breathing, symptom checker', AppColors.mint, () => const _Wrap('Wellness', WellnessTab())),
      ('🧘🏾‍♀️', 'Me time', 'Routines, exercise, reading, hobbies, rest', AppColors.secondary, () => const MeTimeScreen()),
      ('📔', 'MySpace', 'Private diary, reflections, memories, voice notes', AppColors.primary, () => const JournalScreen()),
      ('💰', 'MyPocket', 'Expenses, income, budgets, savings, bills', AppColors.sun, () => const PocketScreen()),
      ('👗', 'MyCloset', 'Wardrobe, outfits, wishlist, what to wear', AppColors.sky, () => const ClosetScreen()),
      ('🎓', 'Learn', 'Data Analysis lessons, labs, AI tutor', AppColors.secondary, () => const _Wrap('Learn', LearnTab())),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Text('Just for you 💗', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          Text('Your life is more than the house. Take a little time for you every day.',
              style: t.bodyMedium?.copyWith(color: AppColors.muted)),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.95,
            children: items
                .map((it) => WhiteCard(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => it.$5())),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: it.$4.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                          child: Text(it.$1, style: const TextStyle(fontSize: 24)),
                        ),
                        const Spacer(),
                        Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(it.$3, maxLines: 3, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ]),
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
            child: const Text('🔒 Your journal, wellness, closet and personal money are private. Nothing here is shared with your family unless you choose to share it.',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Shows a tab widget as its own page.
class _Wrap extends StatelessWidget {
  final String title;
  final Widget child;
  const _Wrap(this.title, this.child);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(toolbarHeight: 44, title: Text(title, style: const TextStyle(fontSize: 16))),
        body: child,
      );
}
