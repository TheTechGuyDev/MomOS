import 'package:material_ui/material_ui.dart';

import '../../core/memory_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/time_utils.dart';
import '../../widgets/ui.dart';

Future<bool?> showReminderSheet(BuildContext context, {Reminder? existing, String? presetTitle}) {
  final title = TextEditingController(text: existing?.title ?? presetTitle ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  DateTime? due = existing?.dueAt ?? _defaultDue();
  var repeat = existing?.repeat ?? 'none';
  var shared = existing?.shared ?? false;
  var level = existing?.level ?? 'gentle';
  var saving = false;

  return showAppSheet<bool>(context, existing == null ? 'New reminder' : 'Edit reminder', (ctx, setS) {
    final now = DateTime.now();
    DateTime at(int addDays, int h, [int m = 0]) =>
        DateTime(now.year, now.month, now.day + addDays, h, m);
    final presets = <(String, DateTime)>[
      ('In 1 hour', now.add(const Duration(hours: 1))),
      if (now.hour < 20) ('Tonight 8 PM', at(0, 20)),
      ('Tomorrow 9 AM', at(1, 9)),
      ('Next week', at(7, 9)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: title,
          autofocus: existing == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'What should I remind you about?'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: notes,
          minLines: 1,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Notes (optional)'),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets
              .map((p) => ActionChip(
                    label: Text(p.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: () => setS(() => due = p.$2),
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),
        DateTimeButton(
          value: due,
          emptyLabel: 'No time (just a to-do)',
          allowClear: true,
          onChanged: (v) => setS(() => due = v),
        ),
        if (due != null) ...[
          const SizedBox(height: 12),
          const Text('Repeat', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          ChipChoices<String>(
            options: const [('none', 'Once'), ('daily', 'Daily'), ('weekly', 'Weekly'), ('monthly', 'Monthly')],
            value: repeat,
            onChanged: (v) => setS(() => repeat = v),
          ),
        ],
        if (due != null) ...[
          const SizedBox(height: 14),
          const Text('How should I remind you?', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final (k, e, l, d) in const [
            ('gentle', '🔔', 'Gentle', 'One soft sound'),
            ('important', '⚠️', 'Important', 'Vibrates and stays on screen until you tap it'),
            ('alarm', '⏰', 'Alarm', 'Keeps ringing until you tap Stop'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: level == k ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: level == k ? AppColors.primary : const Color(0xFFF0E6E9)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setS(() => level = k),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Text(e, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l, style: const TextStyle(fontWeight: FontWeight.w900)),
                          Text(d, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        ]),
                      ),
                      if (level == k) const Icon(Icons.check_circle, color: AppColors.primary),
                    ]),
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: shared,
          onChanged: (v) => setS(() => shared = v),
          title: const Text('Share with family', style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Your partner can see and tick it off too'),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (title.text.trim().isEmpty) return;
                  setS(() => saving = true);
                  try {
                    await MemoryService.saveReminder(
                      id: existing?.id,
                      title: title.text,
                      notes: notes.text,
                      dueAt: due,
                      repeat: repeat,
                      shared: shared,
                      level: level,
                    );
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (_) {
                    setS(() => saving = false);
                    if (ctx.mounted) toast(ctx, 'Could not save. Please try again.');
                  }
                },
          child: Text(existing == null ? 'Save reminder' : 'Save changes'),
        ),
      ],
    );
  });
}

DateTime _defaultDue() {
  final n = DateTime.now().add(const Duration(hours: 1));
  return DateTime(n.year, n.month, n.day, n.hour, 0);
}

class RemindersView extends StatefulWidget {
  const RemindersView({super.key});
  @override
  State<RemindersView> createState() => RemindersViewState();
}

class RemindersViewState extends State<RemindersView> {
  List<Reminder> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await MemoryService.reminders();
      if (mounted) {
        setState(() {
          _items = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Reminder r) async {
    try {
      await MemoryService.setReminderDone(r.id, !r.done);
      if (!r.done && mounted) {
        toast(context, r.repeat == 'none' ? 'Done! +3 XP' : 'Done! Next one is scheduled. +3 XP');
      }
    } catch (_) {
      if (mounted) toast(context, 'Could not update. Please try again.');
    }
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    final endToday = DateTime(now.year, now.month, now.day + 1);
    final open = _items.where((r) => !r.done).toList();
    final overdue = open.where((r) => r.overdue).toList();
    final today = open.where((r) => !r.overdue && r.dueAt != null && r.dueAt!.isBefore(endToday)).toList();
    final later = open.where((r) => r.dueAt != null && !r.dueAt!.isBefore(endToday)).toList();
    final todos = open.where((r) => r.dueAt == null).toList();
    final done = _items.where((r) => r.done).toList()
      ..sort((a, b) => (b.doneAt ?? now).compareTo(a.doneAt ?? now));

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
        children: [
          if (open.isEmpty)
            const EmptyState(
              emoji: '🔔',
              title: 'Nothing to remember right now',
              subtitle: 'Tap + to add a reminder. Shared ones also show on your partner\'s phone.',
            ),
          if (overdue.isNotEmpty) ...[
            const SectionTitle('⚠️ Overdue'),
            ...overdue.map(_tile),
          ],
          if (today.isNotEmpty) ...[
            const SectionTitle('Today'),
            ...today.map(_tile),
          ],
          if (later.isNotEmpty) ...[
            const SectionTitle('Coming up'),
            ...later.map(_tile),
          ],
          if (todos.isNotEmpty) ...[
            const SectionTitle('To-do (no time)'),
            ...todos.map(_tile),
          ],
          if (done.isNotEmpty) ...[
            const SectionTitle('Done this week'),
            ...done.take(15).map(_tile),
          ],
        ],
      ),
    );
  }

  Widget _tile(Reminder r) {
    final mine = r.userId == AppSession.uid;
    String sub;
    if (r.dueAt == null) {
      sub = 'No time set';
    } else {
      final d = r.dueAt!;
      final now = DateTime.now();
      sub = isSameDay(d, now)
          ? clock(d)
          : isSameDay(d, now.add(const Duration(days: 1)))
              ? 'Tomorrow, ${clock(d)}'
              : '${shortDate(d)}, ${clock(d)}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: WhiteCard(
        padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
        onTap: mine || r.shared
            ? () async {
                if (await showReminderSheet(context, existing: r) == true) load();
              }
            : null,
        child: Row(children: [
          Checkbox(
            value: r.done,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            onChanged: (_) => _toggle(r),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                r.title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  decoration: r.done ? TextDecoration.lineThrough : null,
                  color: r.done ? AppColors.muted : AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: r.overdue ? Colors.red.shade400 : AppColors.muted,
                      fontWeight: r.overdue ? FontWeight.w800 : FontWeight.w500,
                    )),
                if (r.level != 'gentle') ...[
                  const SizedBox(width: 6),
                  Text(r.level == 'alarm' ? '⏰ alarm' : '⚠️ important',
                      style: TextStyle(fontSize: 12, color: r.level == 'alarm' ? AppColors.primary : Colors.orange.shade700, fontWeight: FontWeight.w700)),
                ],
                if (r.repeat != 'none') ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.repeat, size: 14, color: AppColors.secondary),
                  Text(' ${r.repeat}', style: const TextStyle(fontSize: 12, color: AppColors.secondary)),
                ],
                if (r.shared) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.people_alt_outlined, size: 14, color: AppColors.mint),
                  Text(mine ? ' shared' : ' from family', style: const TextStyle(fontSize: 12, color: AppColors.mint)),
                ],
              ]),
              if (r.notes != null)
                Text(r.notes!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
          if (mine)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.muted),
              onPressed: () async {
                if (await confirmDelete(context, 'Delete this reminder?', message: r.title)) {
                  await MemoryService.deleteReminder(r.id);
                  load();
                }
              },
            ),
        ]),
      ),
    );
  }
}
