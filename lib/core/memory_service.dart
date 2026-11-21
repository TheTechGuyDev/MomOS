import 'dart:typed_data';

import 'app_events.dart';
import 'profile_service.dart';
import 'session.dart';

class Reminder {
  final String id;
  final String userId;
  final String title;
  final String? notes;
  final DateTime? dueAt;
  final String repeat;
  final bool shared;
  final bool done;
  final DateTime? doneAt;

  Reminder({
    required this.id,
    required this.userId,
    required this.title,
    this.notes,
    this.dueAt,
    required this.repeat,
    required this.shared,
    required this.done,
    this.doneAt,
  });

  factory Reminder.fromMap(Map<String, dynamic> m) => Reminder(
        id: m['id'] as String,
        userId: m['user_id'] as String,
        title: m['title'] as String,
        notes: m['notes'] as String?,
        dueAt: m['due_at'] == null ? null : DateTime.parse(m['due_at'] as String).toLocal(),
        repeat: (m['repeat'] ?? 'none') as String,
        shared: (m['shared'] ?? false) as bool,
        done: (m['done'] ?? false) as bool,
        doneAt: m['done_at'] == null ? null : DateTime.parse(m['done_at'] as String).toLocal(),
      );

  bool get overdue => !done && dueAt != null && dueAt!.isBefore(DateTime.now());
}

class Place {
  final String id;
  final String item;
  final String location;
  final String? photoPath;
  final DateTime updatedAt;
  final String? updatedBy;
  Place(this.id, this.item, this.location, this.photoPath, this.updatedAt, this.updatedBy);

  factory Place.fromMap(Map<String, dynamic> m) => Place(
        m['id'] as String,
        m['item'] as String,
        m['location'] as String,
        m['photo_path'] as String?,
        DateTime.parse(m['updated_at'] as String).toLocal(),
        m['updated_by'] as String?,
      );
}

class Note {
  final String id;
  final String? body;
  final String? audioPath;
  final int? audioSeconds;
  final bool pinned;
  final DateTime createdAt;
  Note(this.id, this.body, this.audioPath, this.audioSeconds, this.pinned, this.createdAt);

  factory Note.fromMap(Map<String, dynamic> m) => Note(
        m['id'] as String,
        m['body'] as String?,
        m['audio_path'] as String?,
        m['audio_seconds'] as int?,
        (m['pinned'] ?? false) as bool,
        DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

class MemoryService {
  // Reminders
  static Future<List<Reminder>> reminders() async {
    final rows = await supa
        .from('reminders')
        .select()
        .or('done.eq.false,done_at.gte.${DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String()}')
        .order('due_at', nullsFirst: false)
        .limit(300);
    return rows.map<Reminder>((r) => Reminder.fromMap(r)).toList();
  }

  static Future<void> saveReminder({
    String? id,
    required String title,
    String? notes,
    DateTime? dueAt,
    String repeat = 'none',
    bool shared = false,
  }) async {
    final data = {
      'title': title.trim(),
      'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
      'due_at': dueAt?.toUtc().toIso8601String(),
      'repeat': dueAt == null ? 'none' : repeat,
      'shared': shared,
    };
    if (id == null) {
      await supa.from('reminders').insert({...data, 'family_id': await Session.familyId()});
    } else {
      await supa.from('reminders').update(data).eq('id', id);
    }
  }

  static Future<void> setReminderDone(String id, bool done) async {
    await supa.from('reminders').update({'done': done}).eq('id', id);
    if (done) AppEvents.bump();
  }

  static Future<void> deleteReminder(String id) => supa.from('reminders').delete().eq('id', id);

  static Future<void> createReminders(List<String> titles, DateTime dueAt) async {
    final fam = await Session.familyId();
    await supa.from('reminders').insert([
      for (final t in titles)
        {'title': t, 'due_at': dueAt.toUtc().toIso8601String(), 'family_id': fam},
    ]);
  }

  // Places
  static Future<List<Place>> places() async {
    final rows = await supa.from('places').select().order('updated_at', ascending: false).limit(500);
    return rows.map<Place>((r) => Place.fromMap(r)).toList();
  }

  static Future<void> savePlace({
    String? id,
    required String item,
    required String location,
    Uint8List? photo,
    String photoExt = 'jpg',
    bool removePhoto = false,
  }) async {
    final fam = await Session.familyId();
    String? path;
    if (photo != null) {
      path = await Session.upload(
        'memory-media',
        'family/$fam/places/${DateTime.now().millisecondsSinceEpoch}.$photoExt',
        photo,
        photoExt,
      );
    }
    final data = {
      'item': item.trim(),
      'location': location.trim(),
      'photo_path': ?path,
      if (removePhoto && path == null) 'photo_path': null,
    };
    if (id == null) {
      await supa.from('places').insert({...data, 'family_id': fam});
      AppEvents.bump();
    } else {
      await supa.from('places').update(data).eq('id', id);
    }
  }

  static Future<void> deletePlace(String id) => supa.from('places').delete().eq('id', id);

  // Notes
  static Future<List<Note>> notes() async {
    final rows = await supa
        .from('notes')
        .select()
        .order('pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(200);
    return rows.map<Note>((r) => Note.fromMap(r)).toList();
  }

  static Future<void> addNote({String? body, Uint8List? audio, String audioExt = 'webm', int? seconds}) async {
    String? path;
    if (audio != null) {
      path = await Session.upload(
        'memory-media',
        '${Session.uid}/voice/${DateTime.now().millisecondsSinceEpoch}.$audioExt',
        audio,
        audioExt,
      );
    }
    await supa.from('notes').insert({
      'body': (body ?? '').trim().isEmpty ? null : body!.trim(),
      'audio_path': path,
      'audio_seconds': seconds,
    });
    AppEvents.bump();
  }

  static Future<void> setPinned(String id, bool pinned) =>
      supa.from('notes').update({'pinned': pinned}).eq('id', id);

  static Future<void> deleteNote(Note n) async {
    await supa.from('notes').delete().eq('id', n.id);
    if (n.audioPath != null) {
      try {
        await supa.storage.from('memory-media').remove([n.audioPath!]);
      } catch (_) {}
    }
  }
}
