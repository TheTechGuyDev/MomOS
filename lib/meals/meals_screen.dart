import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../core/time_utils.dart';
import '../widgets/ui.dart';
import 'dishes.dart';
import 'meals_service.dart';

const _slotNames = {'b': 'Breakfast', 'l': 'Lunch', 'd': 'Dinner'};
const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Dish photo from Wikipedia, with a coloured emoji card while loading or if there is none.
class DishImage extends StatelessWidget {
  final Dish dish;
  final double radius;
  final double emojiSize;
  const DishImage(this.dish, {super.key, this.radius = 16, this.emojiSize = 34});

  Widget _placeholder() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.sun.withValues(alpha: 0.35), AppColors.primary.withValues(alpha: 0.25)],
          ),
        ),
        alignment: Alignment.center,
        child: Text(dish.emoji, style: TextStyle(fontSize: emojiSize)),
      );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: FutureBuilder<String?>(
        future: MealsService.photoFor(dish),
        builder: (context, snap) {
          final url = snap.data;
          if (url == null) return _placeholder();
          return Image.network(
            url,
            fit: BoxFit.cover,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: (_, _, _) => _placeholder(),
            loadingBuilder: (c, child, p) => p == null ? child : _placeholder(),
          );
        },
      ),
    );
  }
}

Future<void> showDishSheet(BuildContext context, Dish d, {VoidCallback? onSwap}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.bg,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (ctx, scroll) {
        final t = Theme.of(ctx).textTheme;
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            AspectRatio(aspectRatio: 16 / 10, child: DishImage(d, radius: 22, emojiSize: 64)),
            const SizedBox(height: 4),
            const Text('Photo: Wikipedia / Wikimedia Commons', style: TextStyle(fontSize: 10, color: AppColors.muted)),
            const SizedBox(height: 10),
            Text(d.name, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Chip(avatar: const Icon(Icons.timer_outlined, size: 16), label: Text('${d.minutes} min')),
              ...d.tags.map((tg) => Chip(label: Text(tagLabels[tg] ?? tg))),
            ]),
            const SectionTitle('Ingredients'),
            ...d.ingredients.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('•  ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900)),
                    Expanded(child: Text(i, style: t.bodyLarge)),
                  ]),
                )),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () async {
                try {
                  final n = await MealsService.addToShopping(d);
                  if (ctx.mounted) toast(ctx, 'Added $n items to the family shopping list 🛒');
                } catch (_) {
                  if (ctx.mounted) toast(ctx, 'Could not add to the shopping list.');
                }
              },
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Add ingredients to shopping list'),
            ),
            const SectionTitle('How to make it'),
            ...d.steps.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: AppColors.primary,
                      child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(e.value, style: t.bodyLarge?.copyWith(height: 1.4))),
                  ]),
                )),
            if (onSwap != null) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  onSwap();
                },
                icon: const Icon(Icons.shuffle),
                label: const Text('Swap for another dish'),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class MealsView extends StatefulWidget {
  const MealsView({super.key});
  @override
  State<MealsView> createState() => _MealsViewState();
}

class _MealsViewState extends State<MealsView> {
  DateTime _week = MealsService.weekStart(DateTime.now());
  MealPlan? _plan;
  bool _loading = true;
  bool _todayOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await MealsService.load(_week);
      if (mounted) setState(() => _plan = p);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _generate() async {
    if (_plan != null && !await confirmDelete(context, 'Make a new plan for this week?', message: 'The current plan will be replaced.')) {
      return;
    }
    final p = MealsService.generate(seed: DateTime.now().millisecondsSinceEpoch);
    setState(() => _plan = p);
    try {
      await MealsService.save(_week, p);
      if (mounted) toast(context, 'New meal plan ready 🍲');
    } catch (_) {
      if (mounted) toast(context, 'Could not save the plan.');
    }
  }

  Future<void> _swap(int day, String slot) async {
    final plan = _plan;
    if (plan == null) return;
    final current = plan['$day']?[slot];
    final options = dishes.where((d) => d.slots.contains(slot) && d.key != current).toList();
    final picked = await showModalBottomSheet<Dish>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.bg,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.7,
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.72, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: options.length,
          itemBuilder: (ctx, i) => GestureDetector(
            onTap: () => Navigator.pop(ctx, options[i]),
            child: Column(children: [
              AspectRatio(aspectRatio: 1, child: DishImage(options[i], radius: 14)),
              const SizedBox(height: 4),
              Text(options[i].name, maxLines: 2, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ),
    );
    if (picked == null) return;
    setState(() => plan['$day'] = {...?plan['$day'], slot: picked.key});
    try {
      await MealsService.save(_week, plan);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final todayIdx = DateTime.now().weekday - 1;
    final isThisWeek = _week == MealsService.weekStart(DateTime.now());
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          Row(children: [
            IconButton(
              onPressed: () {
                _week = _week.subtract(const Duration(days: 7));
                _load();
              },
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                isThisWeek ? 'This week' : 'Week of ${shortDate(_week)}',
                textAlign: TextAlign.center,
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              onPressed: () {
                _week = _week.add(const Duration(days: 7));
                _load();
              },
              icon: const Icon(Icons.chevron_right),
            ),
          ]),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (_plan == null)
            EmptyState(
              emoji: '🍲',
              title: 'No meal plan yet',
              subtitle: 'Get a full week of Nigerian breakfast, lunch and dinner ideas in one tap.',
              action: FilledButton.icon(onPressed: _generate, icon: const Icon(Icons.auto_awesome), label: const Text('Plan my week')),
            )
          else ...[
            Row(children: [
              if (isThisWeek)
                ChipChoices<bool>(
                  options: const [(false, 'Week'), (true, 'Today')],
                  value: _todayOnly,
                  onChanged: (v) => setState(() => _todayOnly = v),
                ),
              const Spacer(),
              TextButton.icon(onPressed: _generate, icon: const Icon(Icons.refresh, size: 18), label: const Text('New plan')),
            ]),
            const SizedBox(height: 6),
            if (_todayOnly && isThisWeek)
              ...['b', 'l', 'd'].map((slot) {
                final d = dishByKey(_plan!['$todayIdx']?[slot] ?? '');
                if (d == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: WhiteCard(
                    padding: const EdgeInsets.all(10),
                    onTap: () => showDishSheet(context, d, onSwap: () => _swap(todayIdx, slot)),
                    child: Row(children: [
                      SizedBox(width: 96, height: 96, child: DishImage(d)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_slotNames[slot]!.toUpperCase(),
                              style: const TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w900, color: AppColors.primary)),
                          Text(d.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          Text('${d.minutes} min · tap for recipe', style: t.bodySmall?.copyWith(color: AppColors.muted)),
                        ]),
                      ),
                    ]),
                  ),
                );
              })
            else ...[
              Row(children: [
                const SizedBox(width: 46),
                for (final s in ['b', 'l', 'd'])
                  Expanded(
                    child: Text(_slotNames[s]!.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.w900, color: AppColors.secondary)),
                  ),
              ]),
              const SizedBox(height: 6),
              for (var day = 0; day < 7; day++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isThisWeek && day == todayIdx ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: isThisWeek && day == todayIdx ? Border.all(color: AppColors.primary.withValues(alpha: 0.4)) : null,
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SizedBox(
                      width: 42,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Text(_dayNames[day],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isThisWeek && day == todayIdx ? AppColors.primary : AppColors.ink)),
                      ),
                    ),
                    for (final s in ['b', 'l', 'd'])
                      Expanded(
                        child: Builder(builder: (context) {
                          final d = dishByKey(_plan!['$day']?[s] ?? '');
                          if (d == null) {
                            return IconButton(onPressed: () => _swap(day, s), icon: const Icon(Icons.add));
                          }
                          return GestureDetector(
                            onTap: () => showDishSheet(context, d, onSwap: () => _swap(day, s)),
                            onLongPress: () => _swap(day, s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(children: [
                                AspectRatio(aspectRatio: 1, child: DishImage(d, radius: 14, emojiSize: 28)),
                                const SizedBox(height: 4),
                                Text(d.name,
                                    maxLines: 2,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, height: 1.2)),
                              ]),
                            ),
                          );
                        }),
                      ),
                  ]),
                ),
              Text('Tap a meal for the recipe. Press and hold to swap it.',
                  textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: AppColors.muted)),
            ],
          ],
        ],
      ),
    );
  }
}
