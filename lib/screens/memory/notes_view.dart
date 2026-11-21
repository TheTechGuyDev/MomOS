import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:record/record.dart';

import '../../core/memory_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/time_utils.dart';
import '../../widgets/ui.dart';

class NotesView extends StatefulWidget {
  const NotesView({super.key});
  @override
  State<NotesView> createState() => NotesViewState();
}

class NotesViewState extends State<NotesView> {
  final _text = TextEditingController();
  List<Note> _notes = [];
  bool _loading = true;
  bool _saving = false;

  // Voice recording
  final _rec = AudioRecorder();
  bool _recording = false;
  int _seconds = 0;
  Timer? _timer;
  String _ext = 'webm';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final n = await MemoryService.notes();
      if (mounted) {
        setState(() {
          _notes = n;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveText() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await MemoryService.addNote(body: _text.text);
      _text.clear();
      if (mounted) toast(context, 'Saved. +2 XP');
      await load();
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      _timer?.cancel();
      final path = await _rec.stop();
      final secs = _seconds;
      setState(() => _recording = false);
      if (path == null || secs < 1) return;
      setState(() => _saving = true);
      try {
        final res = await http.get(Uri.parse(path));
        await MemoryService.addNote(audio: res.bodyBytes, audioExt: _ext, seconds: secs, body: _text.text);
        _text.clear();
        if (mounted) toast(context, 'Voice note saved. +2 XP');
        await load();
      } catch (_) {
        if (mounted) toast(context, 'Could not save the voice note.');
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
    try {
      if (!await _rec.hasPermission()) {
        if (mounted) toast(context, 'Please allow microphone access to record.');
        return;
      }
      AudioEncoder enc = AudioEncoder.opus;
      _ext = 'webm';
      if (!await _rec.isEncoderSupported(AudioEncoder.opus)) {
        enc = AudioEncoder.aacLc;
        _ext = 'm4a';
      }
      await _rec.start(RecordConfig(encoder: enc, numChannels: 1), path: '');
      setState(() {
        _recording = true;
        _seconds = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _seconds++);
        if (_seconds >= 180) _toggleRecording();
      });
    } catch (_) {
      if (mounted) toast(context, 'Recording is not available on this browser.');
    }
  }

  Future<void> _toReminders(Note n) async {
    final lines = (n.body ?? '')
        .split('\n')
        .map((l) => l.replaceFirst(RegExp(r'^\s*([-*•]|\d+[.)])\s*'), '').trim())
        .where((l) => l.length > 1)
        .toList();
    if (lines.isEmpty) return;
    final picked = {for (final l in lines) l: true};
    final now = DateTime.now();
    DateTime due = DateTime(now.year, now.month, now.day + 1, 9);
    final ok = await showAppSheet<bool>(context, 'Turn into reminders', (ctx, setS) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...lines.map((l) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: picked[l],
              onChanged: (v) => setS(() => picked[l] = v ?? false),
              title: Text(l),
            )),
        const SizedBox(height: 8),
        DateTimeButton(value: due, onChanged: (v) => setS(() => due = v ?? due)),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () async {
            final titles = picked.entries.where((e) => e.value).map((e) => e.key).toList();
            if (titles.isEmpty) return;
            try {
              await MemoryService.createReminders(titles, due);
              if (ctx.mounted) Navigator.pop(ctx, true);
            } catch (_) {
              if (ctx.mounted) toast(ctx, 'Could not create reminders.');
            }
          },
          child: const Text('Create reminders'),
        ),
      ]);
    });
    if (ok == true && mounted) toast(context, 'Reminders created. See the Reminders tab.');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          WhiteCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Empty your mind 🧠', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              Text('Write everything on your mind, one thing per line. Turn lines into reminders later.',
                  style: t.bodySmall?.copyWith(color: AppColors.muted)),
              const SizedBox(height: 10),
              TextField(
                controller: _text,
                minLines: 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Buy diapers\nCall mum\nPay school fees...'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _saving || _recording ? null : _saveText,
                    child: const Text('Save note'),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 54,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _recording ? Colors.red.shade100 : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _saving ? null : _toggleRecording,
                    icon: Icon(_recording ? Icons.stop_circle : Icons.mic, color: _recording ? Colors.red : null),
                    label: Text(_recording ? durationClock(_seconds) : 'Voice'),
                  ),
                ),
              ]),
              if (_recording)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Recording... tap stop to save (max 3 minutes)',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 12)),
                ),
            ]),
          ),
          if (_notes.isEmpty)
            const EmptyState(emoji: '📝', title: 'No notes yet', subtitle: 'Your brain dump and voice notes appear here.'),
          if (_notes.isNotEmpty) const SectionTitle('Your notes'),
          ..._notes.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WhiteCard(
                  padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (n.audioPath != null) _VoicePlayer(path: n.audioPath!, seconds: n.audioSeconds ?? 0),
                    if (n.body != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 10, top: 4),
                        child: Text(n.body!, style: t.bodyLarge),
                      ),
                    Row(children: [
                      Text(
                        '${n.pinned ? '📌 ' : ''}${timeAgo(n.createdAt)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const Spacer(),
                      if ((n.body ?? '').trim().isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _toReminders(n),
                          icon: const Icon(Icons.alarm_add, size: 18),
                          label: const Text('Remind me'),
                        ),
                      IconButton(
                        tooltip: n.pinned ? 'Unpin' : 'Pin',
                        icon: Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 20),
                        onPressed: () async {
                          await MemoryService.setPinned(n.id, !n.pinned);
                          load();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
                        onPressed: () async {
                          if (await confirmDelete(context, 'Delete this note?')) {
                            await MemoryService.deleteNote(n);
                            load();
                          }
                        },
                      ),
                    ]),
                  ]),
                ),
              )),
        ],
      ),
    );
  }
}

String durationClock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

class _VoicePlayer extends StatefulWidget {
  final String path;
  final int seconds;
  const _VoicePlayer({required this.path, required this.seconds});
  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _pos = Duration.zero;
  final _subs = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    _subs.add(_player.onPositionChanged.listen((p) => setState(() => _pos = p)));
    _subs.add(_player.onPlayerComplete.listen((_) => setState(() {
          _playing = false;
          _pos = Duration.zero;
        })));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    try {
      if (_playing) {
        await _player.pause();
        setState(() => _playing = false);
      } else {
        final url = await Session.signedUrl('memory-media', widget.path);
        await _player.play(UrlSource(url));
        setState(() => _playing = true);
      }
    } catch (_) {
      if (mounted) toast(context, 'Could not play this voice note.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.seconds <= 0 ? 1 : widget.seconds;
    return Row(children: [
      IconButton.filled(
        onPressed: _toggle,
        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_pos.inMilliseconds / (total * 1000)).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(durationClock(widget.seconds), style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(width: 10),
    ]);
  }
}
