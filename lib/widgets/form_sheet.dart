import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../core/time_utils.dart';
import 'ui.dart';

enum FieldType { text, multiline, number, money, date, datetime, choice, multi, toggle, emoji, photo }

class FieldSpec {
  final String key;
  final String label;
  final FieldType type;
  final List<(String, String)> options; // (value, label)
  final bool required;
  final String? hint;
  const FieldSpec(this.key, this.label, this.type, {this.options = const [], this.required = false, this.hint});
}

/// A generic bottom-sheet form. Returns the values, or null if cancelled.
/// Photos come back as `(Uint8List, String ext)` under their key.
Future<Map<String, dynamic>?> showFormSheet(
  BuildContext context, {
  required String title,
  required List<FieldSpec> fields,
  Map<String, dynamic> initial = const {},
  String saveLabel = 'Save',
  List<String> emojis = const ['🌸', '⭐', '🎯', '🏠', '🧹', '💡', '📌', '❤️', '🎉', '📚', '💪', '🧺'],
}) {
  final values = <String, dynamic>{...initial};
  final controllers = <String, TextEditingController>{};
  for (final f in fields) {
    if ([FieldType.text, FieldType.multiline, FieldType.number, FieldType.money].contains(f.type)) {
      final v = initial[f.key];
      controllers[f.key] = TextEditingController(text: v == null ? '' : (v is num && v == v.roundToDouble() ? '${v.toInt()}' : '$v'));
    }
  }

  return showAppSheet<Map<String, dynamic>>(context, title, (ctx, setS) {
    final widgets = <Widget>[];
    for (final f in fields) {
      switch (f.type) {
        case FieldType.text:
        case FieldType.multiline:
        case FieldType.number:
        case FieldType.money:
          final numeric = f.type == FieldType.number || f.type == FieldType.money;
          widgets.add(TextField(
            controller: controllers[f.key],
            minLines: f.type == FieldType.multiline ? 3 : 1,
            maxLines: f.type == FieldType.multiline ? 8 : 1,
            keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : null,
            textCapitalization: numeric ? TextCapitalization.none : TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: f.label,
              hintText: f.hint,
              prefixText: f.type == FieldType.money ? '₦ ' : null,
            ),
          ));
        case FieldType.date:
        case FieldType.datetime:
          widgets.add(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            DateTimeButton(
              value: values[f.key] as DateTime?,
              dateOnly: f.type == FieldType.date,
              allowClear: !f.required,
              emptyLabel: f.hint ?? 'Pick a date',
              onChanged: (v) => setS(() => values[f.key] = v),
            ),
          ]));
        case FieldType.choice:
          widgets.add(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            ChipChoices<String>(options: f.options, value: values[f.key] as String?, onChanged: (v) => setS(() => values[f.key] = v)),
          ]));
        case FieldType.multi:
          final sel = Set<String>.from((values[f.key] as Iterable?) ?? const []);
          widgets.add(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: f.options
                  .map((o) => FilterChip(
                        label: Text(o.$2),
                        selected: sel.contains(o.$1),
                        onSelected: (v) => setS(() {
                          v ? sel.add(o.$1) : sel.remove(o.$1);
                          values[f.key] = sel.toList();
                        }),
                      ))
                  .toList(),
            ),
          ]));
        case FieldType.toggle:
          widgets.add(SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: (values[f.key] ?? false) as bool,
            onChanged: (v) => setS(() => values[f.key] = v),
            title: Text(f.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: f.hint == null ? null : Text(f.hint!),
          ));
        case FieldType.emoji:
          widgets.add(Wrap(
            spacing: 6,
            runSpacing: 6,
            children: emojis
                .map((e) => GestureDetector(
                      onTap: () => setS(() => values[f.key] = e),
                      child: Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: values[f.key] == e ? AppColors.primary.withValues(alpha: 0.18) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: values[f.key] == e ? AppColors.primary : const Color(0xFFF0E6E9)),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 20)),
                      ),
                    ))
                .toList(),
          ));
        case FieldType.photo:
          final p = values[f.key];
          widgets.add(Row(children: [
            if (p is (Uint8List, String))
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(p.$1, width: 64, height: 64, fit: BoxFit.cover)),
            if (p is (Uint8List, String)) const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: () async {
                  final ph = await pickPhoto(ctx);
                  if (ph != null) setS(() => values[f.key] = ph);
                },
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(p == null ? f.label : 'Change photo'),
              ),
            ),
          ]));
      }
      widgets.add(const SizedBox(height: 12));
    }
    widgets.add(FilledButton(
      onPressed: () {
        for (final f in fields) {
          final c = controllers[f.key];
          if (c != null) {
            final txt = c.text.trim();
            if (f.type == FieldType.number || f.type == FieldType.money) {
              values[f.key] = txt.isEmpty ? null : num.tryParse(txt.replaceAll(',', ''));
            } else {
              values[f.key] = txt.isEmpty ? null : txt;
            }
          }
          if (f.required && (values[f.key] == null || (values[f.key] is String && (values[f.key] as String).isEmpty))) {
            toast(ctx, 'Please fill in "${f.label}"');
            return;
          }
        }
        Navigator.pop(ctx, values);
      },
      child: Text(saveLabel),
    ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets);
  });
}

String naira(num? v) {
  if (v == null) return '₦0';
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '₦$b';
}

String dueLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
  if (diff < 0) return diff == -1 ? 'Overdue (yesterday)' : 'Overdue by ${-diff} days';
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff < 7) return 'In $diff days';
  return shortDate(d);
}
