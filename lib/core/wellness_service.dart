import 'app_events.dart';
import 'profile_service.dart';

class WellnessDay {
  final DateTime day;
  final int water;
  final int waterGoal;
  final double? sleepHours;
  final int? sleepQuality;
  final int breathing;
  final List<String> gratitude;

  WellnessDay(this.day, this.water, this.waterGoal, this.sleepHours, this.sleepQuality, this.breathing, this.gratitude);

  factory WellnessDay.fromMap(Map<String, dynamic> m) => WellnessDay(
        DateTime.parse(m['day'] as String),
        (m['water'] ?? 0) as int,
        (m['water_goal'] ?? 8) as int,
        (m['sleep_hours'] as num?)?.toDouble(),
        m['sleep_quality'] as int?,
        (m['breathing_sessions'] ?? 0) as int,
        List<String>.from((m['gratitude'] ?? []) as List),
      );
}

class MoodLog {
  final String id;
  final int mood;
  final List<String> tags;
  final String? note;
  final DateTime at;
  MoodLog(this.id, this.mood, this.tags, this.note, this.at);

  factory MoodLog.fromMap(Map<String, dynamic> m) => MoodLog(
        m['id'] as String,
        m['mood'] as int,
        List<String>.from((m['tags'] ?? []) as List),
        m['note'] as String?,
        DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

const moodFaces = ['😢', '😕', '😐', '🙂', '😄'];
const moodLabels = ['Very low', 'Low', 'Okay', 'Good', 'Great'];

class WellnessService {
  static Future<WellnessDay> today() async {
    final r = await supa.rpc('wellness_today');
    return WellnessDay.fromMap(Map<String, dynamic>.from(r as Map));
  }

  static Future<(int, WellnessDay)> _call(String fn, [Map<String, dynamic>? params]) async {
    final r = Map<String, dynamic>.from(await supa.rpc(fn, params: params) as Map);
    final gained = (r['gained'] ?? 0) as int;
    if (gained > 0) AppEvents.bump();
    return (gained, WellnessDay.fromMap(Map<String, dynamic>.from(r['row'] as Map)));
  }

  static Future<(int, WellnessDay)> setWater(int count, {int? goal}) =>
      _call('set_water', {'p_count': count, 'p_goal': goal});

  static Future<(int, WellnessDay)> logSleep(double hours, int quality) =>
      _call('log_my_sleep', {'p_hours': hours, 'p_quality': quality});

  static Future<(int, WellnessDay)> breathingDone() => _call('breathing_done');

  static Future<(int, WellnessDay)> addGratitude(String text) => _call('add_gratitude', {'p_text': text});

  static Future<void> logMood(int mood, List<String> tags, String? note) async {
    await supa.from('mood_logs').insert({
      'mood': mood,
      'tags': tags,
      'note': (note ?? '').trim().isEmpty ? null : note!.trim(),
    });
    AppEvents.bump();
  }

  static Future<List<MoodLog>> moods({int days = 14}) async {
    final since = DateTime.now().subtract(Duration(days: days)).toUtc().toIso8601String();
    final rows = await supa.from('mood_logs').select().gte('created_at', since).order('created_at', ascending: false);
    return rows.map<MoodLog>((r) => MoodLog.fromMap(r)).toList();
  }

  static Future<List<WellnessDay>> history({int days = 30}) async {
    final since = DateTime.now().subtract(Duration(days: days));
    final rows = await supa
        .from('daily_wellness')
        .select()
        .gte('day', '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}')
        .order('day', ascending: false);
    return rows.map<WellnessDay>((r) => WellnessDay.fromMap(r)).toList();
  }
}
