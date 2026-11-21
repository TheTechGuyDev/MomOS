import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import '../core/time_utils.dart';

/// Standard bottom sheet used across the app.
Future<T?> showAppSheet<T>(
  BuildContext context,
  String title,
  Widget Function(BuildContext ctx, StateSetter setS) body,
) {
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

class ChipChoices<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T> onChanged;
  const ChipChoices({super.key, required this.options, required this.value, required this.onChanged});

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

/// Date + time picker button. Future dates allowed.
class DateTimeButton extends StatelessWidget {
  final DateTime? value;
  final String emptyLabel;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;
  final bool dateOnly;
  const DateTimeButton({
    super.key,
    required this.value,
    required this.onChanged,
    this.emptyLabel = 'No date',
    this.allowClear = false,
    this.dateOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final v = value;
    String label;
    if (v == null) {
      label = emptyLabel;
    } else {
      final now = DateTime.now();
      final day = isSameDay(v, now)
          ? 'Today'
          : isSameDay(v, now.add(const Duration(days: 1)))
              ? 'Tomorrow'
              : shortDate(v);
      label = dateOnly ? day : '$day at ${clock(v)}';
    }
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: Icon(dateOnly ? Icons.event : Icons.schedule),
          label: Text(label),
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: v ?? now,
              firstDate: now.subtract(const Duration(days: 365)),
              lastDate: now.add(const Duration(days: 730)),
            );
            if (d == null || !context.mounted) return;
            if (dateOnly) {
              onChanged(DateTime(d.year, d.month, d.day));
              return;
            }
            final t = await showTimePicker(
              context: context,
              initialTime: v != null ? TimeOfDay.fromDateTime(v) : const TimeOfDay(hour: 9, minute: 0),
            );
            if (t == null) return;
            onChanged(DateTime(d.year, d.month, d.day, t.hour, t.minute));
          },
        ),
      ),
      if (allowClear && v != null)
        IconButton(onPressed: () => onChanged(null), icon: const Icon(Icons.close)),
    ]);
  }
}

/// Picks a photo from camera or gallery, resized for upload.
Future<(Uint8List, String)?> pickPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: const Text('Take a photo'),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Choose from gallery'),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null) return null;
  final x = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
  if (x == null) return null;
  final bytes = await x.readAsBytes();
  return (bytes, x.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg');
}

class EmptyState extends StatelessWidget {
  final String emoji, title, subtitle;
  final Widget? action;
  const EmptyState({super.key, required this.emoji, required this.title, required this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(children: [
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ),
        ?trailing,
      ]),
    );
  }
}

class WhiteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  const WhiteCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

Future<bool> confirmDelete(BuildContext context, String title, {String? message}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade400),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return ok == true;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), duration: const Duration(milliseconds: 1600)),
  );
}

/// Page header used by each tab.
class TabHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  const TabHeader({super.key, required this.title, this.subtitle, this.action});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            if (subtitle != null) Text(subtitle!, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
          ]),
        ),
        ?action,
      ]),
    );
  }
}
