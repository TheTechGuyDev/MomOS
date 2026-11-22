import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:record/record.dart';

import '../core/life_service.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../core/wellness_service.dart';
import '../widgets/ui.dart';

const _kinds = <(String, String)>[
  ('diary', '📔 Diary'),
  ('reflection', '💭 Reflection'),
  ('memory', '📸 Memory'),
  ('aspiration', '🌟 Dreams & goals'),
];

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});
  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  List<Rec> _entries = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final e = await Life.list('journal_entries', eq: {'user_id': AppSession.uid}, order: 'created_at', ascending: false, limit: 300);
      if (mounted) {
        setState(() {
          _entries = e;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _filter == 'all' ? _entries : _entries.where((e) => e['kind'] == _filter).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('MySpace 📔')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JournalEditor()));
          _load();
        },
        icon: const Icon(Icons.edit),
        label: const Text('Write'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                  child: const Text('🔒 Private. Only you can see your journal, even if your family is linked.', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 10),
                ChipChoices<String>(options: const [('all', 'All'), ..._kinds], value: _filter, onChanged: (v) => setState(() => _filter = v)),
                const SizedBox(height: 10),
                if (shown.isEmpty)
                  const EmptyState(emoji: '📔', title: 'Your private space', subtitle: 'Write how your day went, save a memory with a photo, or record a voice note.'),
                ...shown.map((e) {
                  final at = DateTime.parse('${e['created_at']}').toLocal();
                  final photos = List<String>.from((e['photo_paths'] ?? []) as List);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: WhiteCard(
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => JournalEditor(existing: e)));
                        _load();
                      },
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(_kinds.firstWhere((k) => k.$1 == e['kind'], orElse: () => _kinds.first).$2.split(' ').first,
                              style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${e['title'] ?? shortDate(at)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                          if (e['mood'] != null) Text(moodFaces[(e['mood'] as int) - 1], style: const TextStyle(fontSize: 20)),
                        ]),
                        Text('${shortDate(at)} · ${clock(at)}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                        if ((e['body'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('${e['body']}', maxLines: 4, overflow: TextOverflow.ellipsis),
                        ],
                        if (photos.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 72,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: photos.map((p) => Padding(padding: const EdgeInsets.only(right: 6), child: PrivatePhoto(p, size: 72))).toList(),
                            ),
                          ),
                        ],
                        if (e['audio_path'] != null) const Padding(padding: EdgeInsets.only(top: 6), child: Text('🎙️ Voice note')),
                      ]),
                    ),
                  );
                }),
              ]),
            ),
    );
  }
}

class PrivatePhoto extends StatelessWidget {
  final String path;
  final double size;
  const PrivatePhoto(this.path, {super.key, this.size = 80});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: size,
          height: size,
          child: FutureBuilder<String>(
            future: AppSession.signedUrl('private-media', path),
            builder: (c, s) => s.hasData ? Image.network(s.data!, fit: BoxFit.cover) : Container(color: const Color(0xFFF3E9EC)),
          ),
        ),
      );
}

class JournalEditor extends StatefulWidget {
  final Rec? existing;
  const JournalEditor({super.key, this.existing});
  @override
  State<JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<JournalEditor> {
  late final _title = TextEditingController(text: widget.existing?['title'] as String?);
  late final _body = TextEditingController(text: widget.existing?['body'] as String?);
  late String _kind = (widget.existing?['kind'] ?? 'diary') as String;
  late int? _mood = widget.existing?['mood'] as int?;
  late final List<String> _photoPaths = List<String>.from((widget.existing?['photo_paths'] ?? []) as List);
  final List<(Uint8List, String)> _newPhotos = [];
  late String? _audioPath = widget.existing?['audio_path'] as String?;
  late int? _audioSecs = widget.existing?['audio_seconds'] as int?;
  Uint8List? _newAudio;
  String _audioExt = 'webm';
  final _rec = AudioRecorder();
  final _player = AudioPlayer();
  bool _recording = false;
  int _secs = 0;
  Timer? _timer;
  bool _saving = false;

  static const _prompts = [
    'What made you smile today?',
    'What is one thing you did well today?',
    'What is on your mind right now?',
    'What would make tomorrow a little easier?',
    'Describe a sweet moment with the girls.',
    'What do you want for yourself this year?',
  ];

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleRec() async {
    if (_recording) {
      _timer?.cancel();
      final p = await _rec.stop();
      setState(() => _recording = false);
      if (p != null && _secs > 0) {
        final res = await http.get(Uri.parse(p));
        setState(() {
          _newAudio = res.bodyBytes;
          _audioSecs = _secs;
        });
      }
      return;
    }
    if (!await _rec.hasPermission()) {
      if (mounted) toast(context, 'Please allow the microphone.');
      return;
    }
    var enc = AudioEncoder.opus;
    _audioExt = 'webm';
    if (!await _rec.isEncoderSupported(enc)) {
      enc = AudioEncoder.aacLc;
      _audioExt = 'm4a';
    }
    await _rec.start(RecordConfig(encoder: enc, numChannels: 1), path: '');
    setState(() {
      _recording = true;
      _secs = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secs++);
      if (_secs >= 300) _toggleRec();
    });
  }

  Future<void> _save() async {
    if (_body.text.trim().isEmpty && _newPhotos.isEmpty && _photoPaths.isEmpty && _newAudio == null && _audioPath == null) {
      toast(context, 'Write something, add a photo or record a voice note.');
      return;
    }
    setState(() => _saving = true);
    try {
      for (final p in _newPhotos) {
        _photoPaths.add(await Life.uploadPrivate(p.$1, p.$2, 'journal'));
      }
      if (_newAudio != null) _audioPath = await Life.uploadPrivate(_newAudio!, _audioExt, 'journal-voice');
      final data = {
        'title': _title.text.trim().isEmpty ? null : _title.text.trim(),
        'body': _body.text.trim().isEmpty ? null : _body.text.trim(),
        'kind': _kind,
        'mood': _mood,
        'photo_paths': _photoPaths,
        'audio_path': _audioPath,
        'audio_seconds': _audioSecs,
      };
      if (widget.existing == null) {
        await Life.insert('journal_entries', data, family: false, xp: true);
      } else {
        await Life.update('journal_entries', '${widget.existing!['id']}', data);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Please try again.');
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prompt = _prompts[DateTime.now().day % _prompts.length];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New entry' : 'Edit entry'),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirmDelete(context, 'Delete this entry?')) {
                  await Life.delete('journal_entries', '${widget.existing!['id']}');
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        ChipChoices<String>(options: _kinds, value: _kind, onChanged: (v) => setState(() => _kind = v)),
        const SizedBox(height: 12),
        const Text('How do you feel?', style: TextStyle(fontWeight: FontWeight.w800)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) => IconButton(
                iconSize: 32,
                onPressed: () => setState(() => _mood = i + 1),
                icon: Opacity(opacity: _mood == null || _mood == i + 1 ? 1 : 0.35, child: Text(moodFaces[i], style: const TextStyle(fontSize: 28))),
              )),
        ),
        TextField(controller: _title, decoration: const InputDecoration(hintText: 'Title (optional)')),
        const SizedBox(height: 10),
        TextField(
          controller: _body,
          minLines: 8,
          maxLines: 30,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: prompt),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ..._photoPaths.map((p) => Stack(children: [
                PrivatePhoto(p),
                Positioned(right: 0, top: 0, child: GestureDetector(onTap: () => setState(() => _photoPaths.remove(p)), child: const CircleAvatar(radius: 11, child: Icon(Icons.close, size: 14)))),
              ])),
          ..._newPhotos.map((p) => ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(p.$1, width: 80, height: 80, fit: BoxFit.cover))),
          GestureDetector(
            onTap: () async {
              final p = await pickPhoto(context);
              if (p != null) setState(() => _newPhotos.add(p));
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF0E6E9))),
              child: const Icon(Icons.add_a_photo_outlined),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(backgroundColor: _recording ? Colors.red.shade100 : null),
            onPressed: _toggleRec,
            icon: Icon(_recording ? Icons.stop_circle : Icons.mic, color: _recording ? Colors.red : null),
            label: Text(_recording ? 'Stop (${_secs}s)' : (_newAudio != null || _audioPath != null ? 'Re-record voice note' : 'Voice note')),
          ),
          const SizedBox(width: 8),
          if (_audioPath != null && _newAudio == null)
            IconButton.filledTonal(
              icon: const Icon(Icons.play_arrow),
              onPressed: () async => _player.play(UrlSource(await AppSession.signedUrl('private-media', _audioPath!))),
            ),
          if (_newAudio != null) Text('Voice note ready (${_audioSecs}s)', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}
