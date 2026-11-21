import 'app_events.dart';
import 'profile_service.dart';
import 'time_utils.dart';

class Child {
  final String id;
  final String name;
  final DateTime birthDate;
  final String emoji;
  Child(this.id, this.name, this.birthDate, this.emoji);

  factory Child.fromMap(Map<String, dynamic> m) => Child(
        m['id'] as String,
        m['name'] as String,
        DateTime.parse(m['birth_date'] as String),
        (m['emoji'] ?? '👶') as String,
      );

  int get ageMonths {
    final now = DateTime.now();
    var months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (now.day < birthDate.day) months--;
    return months;
  }

  /// Under 3: breastfeeding, bottles and diapers apply.
  bool get isBaby => ageMonths < 36;
}

class KidLog {
  final String id;
  final String kind;
  final DateTime startedAt;
  final DateTime? endedAt;
  final Map<String, dynamic> data;
  final String? note;

  KidLog(this.id, this.kind, this.startedAt, this.endedAt, this.data, this.note);

  factory KidLog.fromMap(Map<String, dynamic> m) => KidLog(
        m['id'] as String,
        m['kind'] as String,
        DateTime.parse(m['started_at'] as String).toLocal(),
        m['ended_at'] == null ? null : DateTime.parse(m['ended_at'] as String).toLocal(),
        Map<String, dynamic>.from((m['data'] ?? {}) as Map),
        m['note'] as String?,
      );

  String get emoji {
    switch (kind) {
      case 'feed':
        final t = data['type'];
        if (t == 'meal') return '🍽️';
        if (t == 'bottle') return '🍼';
        if (t == 'solids') return '🥣';
        return '🤱';
      case 'sleep':
        return '😴';
      case 'diaper':
        return data['type'] == 'dirty' ? '💩' : (data['type'] == 'both' ? '🧷' : '💧');
      case 'growth':
        return '📏';
      case 'health':
        return '🌡️';
    }
    return '📝';
  }

  String get title {
    switch (kind) {
      case 'feed':
        switch (data['type']) {
          case 'breast_left':
            return 'Breastfeed (left)${_mins()}';
          case 'breast_right':
            return 'Breastfeed (right)${_mins()}';
          case 'bottle':
            return 'Bottle${data['ml'] != null ? ' · ${data['ml']} ml' : ''}';
          case 'solids':
            return 'Solids${(data['food'] ?? '').toString().isNotEmpty ? ' · ${data['food']}' : ''}';
          case 'meal':
            final meal = const {
                  'breakfast': 'Breakfast',
                  'lunch': 'Lunch',
                  'dinner': 'Dinner',
                  'snack': 'Snack',
                }[data['meal']] ??
                'Meal';
            return '$meal${(data['food'] ?? '').toString().isNotEmpty ? ' · ${data['food']}' : ''}';
        }
        return 'Feed';
      case 'sleep':
        if (endedAt == null) return 'Sleeping now';
        return 'Slept ${durationText(endedAt!.difference(startedAt))}';
      case 'diaper':
        return {'wet': 'Wet diaper', 'dirty': 'Dirty diaper', 'both': 'Wet + dirty diaper'}[data['type']] ??
            'Diaper';
      case 'growth':
        final parts = <String>[
          if (data['weight_kg'] != null) '${data['weight_kg']} kg',
          if (data['height_cm'] != null) '${data['height_cm']} cm',
          if (data['head_cm'] != null) 'head ${data['head_cm']} cm',
        ];
        return 'Growth · ${parts.join(' · ')}';
      case 'health':
        final parts = <String>[
          if (data['temp_c'] != null) '${data['temp_c']}°C',
          if ((data['medicine'] ?? '').toString().isNotEmpty) '${data['medicine']}',
          if ((data['symptoms'] ?? '').toString().isNotEmpty) '${data['symptoms']}',
        ];
        return 'Health · ${parts.join(' · ')}';
    }
    return kind;
  }

  String _mins() => data['minutes'] != null ? ' · ${data['minutes']} min' : '';
}

class KidTask {
  final String id;
  final String title;
  final String category;
  final DateTime? dueDate;
  final bool done;
  KidTask(this.id, this.title, this.category, this.dueDate, this.done);

  factory KidTask.fromMap(Map<String, dynamic> m) => KidTask(
        m['id'] as String,
        m['title'] as String,
        m['category'] as String,
        m['due_date'] == null ? null : DateTime.parse(m['due_date'] as String),
        m['done'] as bool,
      );

  String get emoji => const {
        'homework': '📚',
        'school_event': '🏫',
        'activity': '⚽',
        'other': '📌',
      }[category] ??
      '📌';
}

class KidsService {
  static String? _familyId;

  static Future<String> _family() async {
    if (_familyId != null) return _familyId!;
    final p = await ProfileService.me();
    _familyId = p!.familyId!;
    return _familyId!;
  }

  static Future<List<Child>> children() async {
    final rows = await supa.from('children').select().order('birth_date');
    return rows.map<Child>((r) => Child.fromMap(r)).toList();
  }

  static Future<void> addChild(String name, DateTime birth, String emoji) async {
    await supa.from('children').insert({
      'family_id': await _family(),
      'name': name,
      'birth_date': dateKey(birth),
      'emoji': emoji,
    });
  }

  static Future<void> updateChild(String id, String name, DateTime birth, String emoji) async {
    await supa.from('children').update({
      'name': name,
      'birth_date': dateKey(birth),
      'emoji': emoji,
    }).eq('id', id);
  }

  static Future<void> deleteChild(String id) => supa.from('children').delete().eq('id', id);

  static Future<List<KidLog>> logs(String childId, {DateTime? since, String? kind, int limit = 200}) async {
    var q = supa.from('kid_logs').select().eq('child_id', childId);
    if (since != null) q = q.gte('started_at', since.toUtc().toIso8601String());
    if (kind != null) q = q.eq('kind', kind);
    final rows = await q.order('started_at', ascending: false).limit(limit);
    return rows.map<KidLog>((r) => KidLog.fromMap(r)).toList();
  }

  static Future<KidLog?> latest(String childId, String kind) async {
    final rows = await supa
        .from('kid_logs')
        .select()
        .eq('child_id', childId)
        .eq('kind', kind)
        .order('started_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : KidLog.fromMap(rows.first);
  }

  static Future<KidLog?> latestMedicine(String childId) async {
    final rows = await supa
        .from('kid_logs')
        .select()
        .eq('child_id', childId)
        .eq('kind', 'health')
        .neq('data->>medicine', '')
        .not('data->>medicine', 'is', null)
        .order('started_at', ascending: false)
        .limit(1);
    return rows.isEmpty ? null : KidLog.fromMap(rows.first);
  }

  static Future<void> addLog(
    String childId,
    String kind, {
    Map<String, dynamic> data = const {},
    DateTime? startedAt,
    DateTime? endedAt,
    String? note,
  }) async {
    await supa.from('kid_logs').insert({
      'family_id': await _family(),
      'child_id': childId,
      'kind': kind,
      'data': data,
      'started_at': (startedAt ?? DateTime.now()).toUtc().toIso8601String(),
      if (endedAt != null) 'ended_at': endedAt.toUtc().toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    AppEvents.bump();
  }

  static Future<void> endSleep(String logId) async {
    await supa
        .from('kid_logs')
        .update({'ended_at': DateTime.now().toUtc().toIso8601String()}).eq('id', logId);
  }

  static Future<void> deleteLog(String id) => supa.from('kid_logs').delete().eq('id', id);

  static Future<List<KidTask>> tasks(String childId) async {
    final rows = await supa
        .from('kid_tasks')
        .select()
        .eq('child_id', childId)
        .order('done')
        .order('due_date', nullsFirst: false)
        .limit(200);
    return rows.map<KidTask>((r) => KidTask.fromMap(r)).toList();
  }

  static Future<void> addTask(String childId, String title, String category, DateTime? due) async {
    await supa.from('kid_tasks').insert({
      'family_id': await _family(),
      'child_id': childId,
      'title': title,
      'category': category,
      if (due != null) 'due_date': dateKey(due),
    });
  }

  static Future<void> setTaskDone(String id, bool done) async {
    await supa.from('kid_tasks').update({'done': done}).eq('id', id);
    if (done) AppEvents.bump();
  }

  static Future<void> deleteTask(String id) => supa.from('kid_tasks').delete().eq('id', id);

  static Future<Map<String, DateTime>> vaccinations(String childId) async {
    final rows = await supa.from('vaccinations').select().eq('child_id', childId);
    return {
      for (final r in rows) r['vaccine_key'] as String: DateTime.parse(r['given_on'] as String),
    };
  }

  static Future<void> markVaccine(String childId, String key, DateTime givenOn) async {
    await supa.from('vaccinations').insert({
      'family_id': await _family(),
      'child_id': childId,
      'vaccine_key': key,
      'given_on': dateKey(givenOn),
    });
    AppEvents.bump();
  }

  static Future<void> unmarkVaccine(String childId, String key) =>
      supa.from('vaccinations').delete().eq('child_id', childId).eq('vaccine_key', key);
}
