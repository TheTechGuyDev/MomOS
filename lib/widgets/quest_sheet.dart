import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/game_service.dart';
import '../core/quests.dart';
import '../core/theme.dart';

/// Opens the proof sheet for a quest. Returns the XP result when completed.
Future<XpResult?> showQuestProofSheet(BuildContext context, Quest quest) {
  return showModalBottomSheet<XpResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.bg,
    builder: (_) => _QuestProofSheet(quest: quest),
  );
}

/// Shows what was submitted for a completed quest.
Future<void> showQuestEntrySheet(BuildContext context, Quest quest) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.bg,
    builder: (ctx) => FutureBuilder<QuestEntry?>(
      future: GameService.questEntry(quest.key),
      builder: (ctx, snap) {
        final t = Theme.of(ctx).textTheme;
        final e = snap.data;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Text(quest.emoji, style: const TextStyle(fontSize: 30)),
                const SizedBox(width: 10),
                Expanded(child: Text(quest.title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                const Icon(Icons.check_circle, color: AppColors.mint),
              ]),
              const SizedBox(height: 16),
              if (snap.connectionState != ConnectionState.done)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              else if (e == null)
                Text('Completed today.', style: t.bodyMedium?.copyWith(color: AppColors.muted))
              else ...[
                if (e.note != null)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Text(e.note!, style: t.bodyLarge),
                  ),
                if (e.photoUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(e.photoUrl!, fit: BoxFit.cover, height: 320),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    ),
  );
}

class _QuestProofSheet extends StatefulWidget {
  final Quest quest;
  const _QuestProofSheet({required this.quest});
  @override
  State<_QuestProofSheet> createState() => _QuestProofSheetState();
}

class _QuestProofSheetState extends State<_QuestProofSheet> {
  String _mode = 'write';
  final _note = TextEditingController();
  Uint8List? _photo;
  String _photoExt = 'jpg';
  bool _saving = false;

  Future<void> _pick(ImageSource source) async {
    try {
      final x = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final name = x.name.toLowerCase();
      setState(() {
        _photo = bytes;
        _photoExt = name.endsWith('.png') ? 'png' : 'jpg';
      });
    } catch (_) {
      _toast('Could not open the photo. Please try again.');
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  bool get _ready => _mode == 'write' ? _note.text.trim().length >= 3 : _photo != null;

  Future<void> _submit() async {
    if (!_ready) return;
    setState(() => _saving = true);
    try {
      final r = await GameService.completeQuest(
        widget.quest.key,
        note: _mode == 'write' ? _note.text.trim() : null,
        photoBytes: _mode == 'photo' ? _photo : null,
        photoExt: _photoExt,
      );
      if (mounted) Navigator.of(context).pop(r);
    } on PostgrestException catch (e) {
      _toast(e.message);
      setState(() => _saving = false);
    } catch (_) {
      _toast('Could not save. Check your connection and try again.');
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = widget.quest;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Text(q.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(q.title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                  Text(q.hint, style: t.bodySmall?.copyWith(color: AppColors.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 18),
            Text('How do you want to complete it?', style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _OptionCard(
                  emoji: '✍️',
                  title: 'Write it here',
                  subtitle: 'List what you plan or did',
                  selected: _mode == 'write',
                  onTap: () => setState(() => _mode = 'write'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OptionCard(
                  emoji: '📷',
                  title: 'Upload a photo',
                  subtitle: 'Already written somewhere',
                  selected: _mode == 'photo',
                  onTap: () => setState(() => _mode = 'photo'),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            if (_mode == 'write')
              TextField(
                controller: _note,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: _hintFor(q.key)),
              )
            else ...[
              if (_photo != null)
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(_photo!, height: 240, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: () => setState(() => _photo = null),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                ])
              else
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Take photo'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('From gallery'),
                    ),
                  ),
                ]),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _ready && !_saving ? _submit : null,
              child: _saving
                  ? const SizedBox(
                      width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Complete quest · +15 XP'),
            ),
          ],
        ),
      ),
    );
  }

  String _hintFor(String key) {
    switch (key) {
      case 'plan_tomorrow':
        return '1. \n2. \n3. ';
      case 'gratitude':
        return 'Today I am grateful for...';
      case 'water_8':
        return 'e.g. 8 glasses, mostly while feeding';
      case 'call_friend':
        return 'Who did you talk to?';
      case 'story_time':
        return 'Which story did you read together?';
      case 'eat_breakfast':
      case 'fruit':
        return 'What did you eat?';
      case 'music':
        return 'Which song?';
      default:
        return 'Write what you did or plan to do...';
    }
  }
}

class _OptionCard extends StatelessWidget {
  final String emoji, title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _OptionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.primary : const Color(0xFFF0E6E9), width: selected ? 2 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
    );
  }
}
