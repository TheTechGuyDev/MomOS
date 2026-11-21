import 'package:material_ui/material_ui.dart';

import '../../core/kids_service.dart';
import '../../core/theme.dart';
import '../../core/time_utils.dart';
import 'log_sheets.dart';

class TasksView extends StatefulWidget {
  final Child child;
  const TasksView({super.key, required this.child});
  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  List<KidTask> _tasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TasksView old) {
    super.didUpdateWidget(old);
    if (old.child.id != widget.child.id) _load();
  }

  Future<void> _load() async {
    try {
      final t = await KidsService.tasks(widget.child.id);
      if (mounted) {
        setState(() {
          _tasks = t;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(KidTask task) async {
    setState(() {
      final i = _tasks.indexWhere((x) => x.id == task.id);
      _tasks[i] = KidTask(task.id, task.title, task.category, task.dueDate, !task.done);
    });
    try {
      await KidsService.setTaskDone(task.id, !task.done);
      if (!task.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Done! +5 XP'), duration: Duration(seconds: 1)),
        );
      }
    } catch (_) {}
    await _load();
  }

  String _dueLabel(DateTime? d) {
    if (d == null) return 'No date';
    final today = DateTime.now();
    final diff = DateTime(d.year, d.month, d.day).difference(DateTime(today.year, today.month, today.day)).inDays;
    if (diff < 0) return 'Overdue · ${shortDate(d)}';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) return 'In $diff days';
    return shortDate(d);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final open = _tasks.where((x) => !x.done).toList();
    final done = _tasks.where((x) => x.done).take(15).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          FilledButton.icon(
            onPressed: () async {
              if (await showTaskSheet(context, widget.child) == true) _load();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add school or activity task'),
          ),
          const SizedBox(height: 18),
          if (open.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Text('🎒', style: TextStyle(fontSize: 44)),
                const SizedBox(height: 8),
                Text('No open tasks for ${widget.child.name}',
                    textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
              ]),
            ),
          ...open.map((x) => _TaskTile(task: x, due: _dueLabel(x.dueDate), onToggle: () => _toggle(x), onDelete: () async {
                await KidsService.deleteTask(x.id);
                _load();
              })),
          if (done.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Done', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900, color: AppColors.muted)),
            const SizedBox(height: 8),
            ...done.map((x) => _TaskTile(task: x, due: _dueLabel(x.dueDate), onToggle: () => _toggle(x), onDelete: () async {
                  await KidsService.deleteTask(x.id);
                  _load();
                })),
          ],
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  final KidTask task;
  final String due;
  final VoidCallback onToggle, onDelete;
  const _TaskTile({required this.task, required this.due, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final overdue = due.startsWith('Overdue') && !task.done;
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Checkbox(
          value: task.done,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          onChanged: (_) => onToggle(),
        ),
        title: Text(
          '${task.emoji} ${task.title}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            decoration: task.done ? TextDecoration.lineThrough : null,
            color: task.done ? AppColors.muted : AppColors.ink,
          ),
        ),
        subtitle: Text(due,
            style: TextStyle(
                color: overdue ? Colors.red.shade400 : AppColors.muted,
                fontWeight: overdue ? FontWeight.w800 : FontWeight.w500)),
        trailing: IconButton(icon: const Icon(Icons.close, size: 20, color: AppColors.muted), onPressed: onDelete),
      ),
    );
  }
}
