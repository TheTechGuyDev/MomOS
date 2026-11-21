import 'package:material_ui/material_ui.dart';

import '../../core/kids_service.dart';
import '../../core/theme.dart';
import '../../core/time_utils.dart';

/// Shared bottom-sheet frame.
Future<T?> _sheet<T>(BuildContext context, String title, Widget Function(BuildContext, StateSetter) body) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.bg,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              body(ctx, setS),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ChoiceChips<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T> onChanged;
  const _ChoiceChips({required this.options, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((o) => ChoiceChip(
                label: Text(o.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                selected: value == o.$1,
                onSelected: (_) => onChanged(o.$1),
              ))
          .toList(),
    );
  }
}

class _WhenPicker extends StatelessWidget {
  final DateTime when;
  final ValueChanged<DateTime> onChanged;
  const _WhenPicker({required this.when, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.schedule),
      label: Text(isSameDay(when, DateTime.now())
          ? 'Today at ${clock(when)}'
          : '${shortDate(when)} at ${clock(when)}'),
      onPressed: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: when,
          firstDate: DateTime.now().subtract(const Duration(days: 60)),
          lastDate: DateTime.now(),
        );
        if (d == null || !context.mounted) return;
        final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(when));
        if (t == null) return;
        onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
      },
    );
  }
}

Future<bool> _save(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
    if (context.mounted) Navigator.of(context).pop(true);
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not save. Please try again.')));
    }
    return false;
  }
}

Future<bool?> showFeedSheet(BuildContext context, Child child) {
  var type = 'breast_left';
  int? minutes = 15;
  final ml = TextEditingController();
  final food = TextEditingController();
  final note = TextEditingController();
  var when = DateTime.now();
  var saving = false;

  return _sheet<bool>(context, 'Log a feed for ${child.name}', (ctx, setS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceChips<String>(
          options: const [
            ('breast_left', '🤱 Left'),
            ('breast_right', '🤱 Right'),
            ('bottle', '🍼 Bottle'),
            ('solids', '🥣 Solids'),
          ],
          value: type,
          onChanged: (v) => setS(() => type = v),
        ),
        const SizedBox(height: 16),
        if (type.startsWith('breast')) ...[
          const Text('How long?', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _ChoiceChips<int>(
            options: const [(5, '5 min'), (10, '10 min'), (15, '15 min'), (20, '20 min'), (30, '30 min'), (45, '45 min')],
            value: minutes,
            onChanged: (v) => setS(() => minutes = v),
          ),
        ],
        if (type == 'bottle')
          TextField(
            controller: ml,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Amount in ml (e.g. 90)'),
          ),
        if (type == 'solids')
          TextField(
            controller: food,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'What did she eat? (e.g. pap, mashed beans)'),
          ),
        const SizedBox(height: 12),
        _WhenPicker(when: when, onChanged: (v) => setS(() => when = v)),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: const InputDecoration(hintText: 'Note (optional)')),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  setS(() => saving = true);
                  final ok = await _save(ctx, () => KidsService.addLog(
                        child.id,
                        'feed',
                        startedAt: when,
                        note: note.text,
                        data: {
                          'type': type,
                          if (type.startsWith('breast')) 'minutes': minutes,
                          if (type == 'bottle' && int.tryParse(ml.text) != null) 'ml': int.parse(ml.text),
                          if (type == 'solids') 'food': food.text.trim(),
                        },
                      ));
                  if (!ok) setS(() => saving = false);
                },
          child: const Text('Save feed'),
        ),
      ],
    );
  });
}

Future<bool?> showMealSheet(BuildContext context, Child child) {
  final h = DateTime.now().hour;
  var meal = h < 11 ? 'breakfast' : (h < 16 ? 'lunch' : 'dinner');
  final food = TextEditingController();
  final note = TextEditingController();
  var when = DateTime.now();
  var saving = false;

  return _sheet<bool>(context, 'Log a meal for ${child.name}', (ctx, setS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceChips<String>(
          options: const [
            ('breakfast', '🍳 Breakfast'),
            ('lunch', '🍛 Lunch'),
            ('dinner', '🍲 Dinner'),
            ('snack', '🍪 Snack'),
          ],
          value: meal,
          onChanged: (v) => setS(() => meal = v),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: food,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'What did she eat? (e.g. jollof rice and plantain)'),
        ),
        const SizedBox(height: 12),
        _WhenPicker(when: when, onChanged: (v) => setS(() => when = v)),
        const SizedBox(height: 12),
        TextField(controller: note, decoration: const InputDecoration(hintText: 'Note (optional), e.g. ate half')),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  setS(() => saving = true);
                  final ok = await _save(ctx, () => KidsService.addLog(
                        child.id,
                        'feed',
                        startedAt: when,
                        note: note.text,
                        data: {'type': 'meal', 'meal': meal, 'food': food.text.trim()},
                      ));
                  if (!ok) setS(() => saving = false);
                },
          child: const Text('Save meal'),
        ),
      ],
    );
  });
}

Future<bool?> showDiaperSheet(BuildContext context, Child child) {
  var when = DateTime.now();
  var saving = false;
  return _sheet<bool>(context, 'Diaper change', (ctx, setS) {
    Widget btn(String type, String emoji, String label) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: saving
                    ? null
                    : () async {
                        setS(() => saving = true);
                        final ok = await _save(ctx,
                            () => KidsService.addLog(child.id, 'diaper', startedAt: when, data: {'type': type}));
                        if (!ok) setS(() => saving = false);
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(children: [
                    Text(emoji, style: const TextStyle(fontSize: 36)),
                    const SizedBox(height: 6),
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [btn('wet', '💧', 'Wet'), btn('dirty', '💩', 'Dirty'), btn('both', '🧷', 'Both')]),
        const SizedBox(height: 14),
        _WhenPicker(when: when, onChanged: (v) => setS(() => when = v)),
      ],
    );
  });
}

Future<bool?> showGrowthSheet(BuildContext context, Child child) {
  final w = TextEditingController();
  final h = TextEditingController();
  final head = TextEditingController();
  var when = DateTime.now();
  var saving = false;
  double? num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));

  return _sheet<bool>(context, 'Growth for ${child.name}', (ctx, setS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: w,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Weight (kg), e.g. 6.4', prefixIcon: Icon(Icons.monitor_weight_outlined)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: h,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Height (cm), e.g. 62', prefixIcon: Icon(Icons.height)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: head,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Head (cm), optional', prefixIcon: Icon(Icons.face_outlined)),
        ),
        const SizedBox(height: 12),
        _WhenPicker(when: when, onChanged: (v) => setS(() => when = v)),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (num(w) == null && num(h) == null && num(head) == null) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Enter at least one measurement.')));
                    return;
                  }
                  setS(() => saving = true);
                  final ok = await _save(ctx, () => KidsService.addLog(child.id, 'growth', startedAt: when, data: {
                        if (num(w) != null) 'weight_kg': num(w),
                        if (num(h) != null) 'height_cm': num(h),
                        if (num(head) != null) 'head_cm': num(head),
                      }));
                  if (!ok) setS(() => saving = false);
                },
          child: const Text('Save measurement'),
        ),
      ],
    );
  });
}

Future<bool?> showHealthSheet(BuildContext context, Child child) {
  final temp = TextEditingController();
  final med = TextEditingController();
  final symptoms = TextEditingController();
  var when = DateTime.now();
  var saving = false;

  return _sheet<bool>(context, 'Health note for ${child.name}', (ctx, setS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: temp,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Temperature (°C), e.g. 37.8', prefixIcon: Icon(Icons.thermostat)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: med,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              hintText: 'Medicine given and amount, as on the label', prefixIcon: Icon(Icons.medication_outlined)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: symptoms,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Symptoms or notes', prefixIcon: Icon(Icons.notes)),
        ),
        const SizedBox(height: 12),
        _WhenPicker(when: when, onChanged: (v) => setS(() => when = v)),
        const SizedBox(height: 8),
        const Text(
          'This is a record only. For dosing, follow the label or ask a pharmacist or doctor.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  final t = double.tryParse(temp.text.replaceAll(',', '.'));
                  if (t == null && med.text.trim().isEmpty && symptoms.text.trim().isEmpty) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(const SnackBar(content: Text('Add a temperature, medicine or note.')));
                    return;
                  }
                  setS(() => saving = true);
                  final ok = await _save(ctx, () => KidsService.addLog(child.id, 'health', startedAt: when, data: {
                        'temp_c': ?t,
                        if (med.text.trim().isNotEmpty) 'medicine': med.text.trim(),
                        if (symptoms.text.trim().isNotEmpty) 'symptoms': symptoms.text.trim(),
                      }));
                  if (!ok) setS(() => saving = false);
                },
          child: const Text('Save health note'),
        ),
      ],
    );
  });
}

Future<bool?> showSleepSheet(BuildContext context, Child child) {
  var start = DateTime.now().subtract(const Duration(hours: 1));
  var end = DateTime.now();
  var saving = false;
  return _sheet<bool>(context, 'Add a past sleep', (ctx, setS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Fell asleep', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        _WhenPicker(when: start, onChanged: (v) => setS(() => start = v)),
        const SizedBox(height: 12),
        const Text('Woke up', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        _WhenPicker(when: end, onChanged: (v) => setS(() => end = v)),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (!end.isAfter(start)) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(const SnackBar(content: Text('Wake time must be after sleep time.')));
                    return;
                  }
                  setS(() => saving = true);
                  final ok = await _save(
                      ctx, () => KidsService.addLog(child.id, 'sleep', startedAt: start, endedAt: end));
                  if (!ok) setS(() => saving = false);
                },
          child: const Text('Save sleep'),
        ),
      ],
    );
  });
}

const childEmojis = ['👶', '👧', '🧒', '👦', '🌸', '🦋', '🐣', '⭐', '🌈', '🐰'];

Future<bool?> showChildSheet(BuildContext context, {Child? existing}) {
  final name = TextEditingController(text: existing?.name ?? '');
  var birth = existing?.birthDate;
  var emoji = existing?.emoji ?? '👶';
  var saving = false;

  return _sheet<bool>(context, existing == null ? 'Add a child' : 'Edit ${existing.name}', (ctx, setS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: childEmojis
              .map((e) => GestureDetector(
                    onTap: () => setS(() => emoji = e),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: emoji == e ? AppColors.primary.withValues(alpha: 0.18) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: emoji == e ? AppColors.primary : const Color(0xFFF0E6E9)),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: "Child's name"),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.cake_outlined),
          label: Text(birth == null ? 'Date of birth' : 'Born ${shortDate(birth!)}'),
          onPressed: () async {
            final d = await showDatePicker(
              context: ctx,
              initialDate: birth ?? DateTime.now(),
              firstDate: DateTime(2005),
              lastDate: DateTime.now(),
            );
            if (d != null) setS(() => birth = d);
          },
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (name.text.trim().isEmpty || birth == null) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(const SnackBar(content: Text('Add a name and date of birth.')));
                    return;
                  }
                  setS(() => saving = true);
                  final ok = await _save(
                    ctx,
                    () => existing == null
                        ? KidsService.addChild(name.text.trim(), birth!, emoji)
                        : KidsService.updateChild(existing.id, name.text.trim(), birth!, emoji),
                  );
                  if (!ok) setS(() => saving = false);
                },
          child: Text(existing == null ? 'Add child' : 'Save changes'),
        ),
      ],
    );
  });
}

Future<bool?> showTaskSheet(BuildContext context, Child child) {
  final title = TextEditingController();
  var category = 'homework';
  DateTime? due = DateTime.now().add(const Duration(days: 1));
  var saving = false;

  return _sheet<bool>(context, 'New task for ${child.name}', (ctx, setS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceChips<String>(
          options: const [
            ('homework', '📚 Homework'),
            ('school_event', '🏫 School event'),
            ('activity', '⚽ Activity'),
            ('other', '📌 Other'),
          ],
          value: category,
          onChanged: (v) => setS(() => category = v),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: title,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Bring crayons, PTA meeting, swimming'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.event),
          label: Text(due == null ? 'No due date' : 'Due ${shortDate(due!)}'),
          onPressed: () async {
            final d = await showDatePicker(
              context: ctx,
              initialDate: due ?? DateTime.now(),
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) setS(() => due = d);
          },
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (title.text.trim().isEmpty) return;
                  setS(() => saving = true);
                  final ok = await _save(ctx, () => KidsService.addTask(child.id, title.text.trim(), category, due));
                  if (!ok) setS(() => saving = false);
                },
          child: const Text('Add task'),
        ),
      ],
    );
  });
}
