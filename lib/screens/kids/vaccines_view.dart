import 'package:material_ui/material_ui.dart';

import '../../core/kids_service.dart';
import '../../core/theme.dart';
import '../../core/time_utils.dart';
import '../../core/vaccines.dart';

class VaccinesView extends StatefulWidget {
  final Child child;
  const VaccinesView({super.key, required this.child});
  @override
  State<VaccinesView> createState() => _VaccinesViewState();
}

class _VaccinesViewState extends State<VaccinesView> {
  Map<String, DateTime> _given = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(VaccinesView old) {
    super.didUpdateWidget(old);
    if (old.child.id != widget.child.id) _load();
  }

  Future<void> _load() async {
    try {
      final g = await KidsService.vaccinations(widget.child.id);
      if (mounted) {
        setState(() {
          _given = g;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Vaccine v) async {
    try {
      if (_given.containsKey(v.key)) {
        await KidsService.unmarkVaccine(widget.child.id, v.key);
      } else {
        final due = widget.child.birthDate.add(Duration(days: v.ageWeeks * 7));
        final d = await showDatePicker(
          context: context,
          helpText: 'When was ${v.name} given?',
          initialDate: due.isAfter(DateTime.now()) ? DateTime.now() : due,
          firstDate: widget.child.birthDate,
          lastDate: DateTime.now(),
        );
        if (d == null) return;
        await KidsService.markVaccine(widget.child.id, v.key, d);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vaccine recorded! +10 XP'), duration: Duration(seconds: 1)),
          );
        }
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not save. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final birth = widget.child.birthDate;
    final now = DateTime.now();
    final done = vaccineSchedule.where((v) => _given.containsKey(v.key)).length;
    final overdue = vaccineSchedule
        .where((v) => !_given.containsKey(v.key) && birth.add(Duration(days: v.ageWeeks * 7)).isBefore(now))
        .length;

    final groups = <String, List<Vaccine>>{};
    for (final v in vaccineSchedule) {
      groups.putIfAbsent(v.ageLabel, () => []).add(v);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  value: done / vaccineSchedule.length,
                  strokeWidth: 7,
                  backgroundColor: AppColors.mint.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation(AppColors.mint),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$done of ${vaccineSchedule.length} recorded',
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    Text(
                      overdue == 0 ? 'Nothing overdue' : '$overdue past their due age, check the clinic card',
                      style: t.bodySmall?.copyWith(color: overdue == 0 ? AppColors.mint : Colors.red.shade400, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Nigeria routine schedule. Always follow your clinic card and health worker.',
            style: t.bodySmall?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 12),
        ...groups.entries.map((g) {
          final due = birth.add(Duration(days: g.value.first.ageWeeks * 7));
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Text('${g.key} · ${shortDate(due)}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
              ),
              ...g.value.map((v) {
                final given = _given[v.key];
                final late = given == null && due.isBefore(now);
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: CheckboxListTile(
                    value: given != null,
                    onChanged: (_) => _toggle(v),
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      given != null ? 'Given ${shortDate(given)}' : (late ? 'Due already' : 'Upcoming'),
                      style: TextStyle(color: late ? Colors.red.shade400 : AppColors.muted),
                    ),
                  ),
                );
              }),
            ],
          );
        }),
      ],
    );
  }
}
