import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_service.dart';
import 'quests.dart';
import 'time_utils.dart';

class GameStats {
  final int xp;
  final int currentStreak;
  final int bestStreak;
  final bool checkedInToday;
  final Set<String> questsDoneToday;
  final int xpToday;
  final Set<String> badges;

  GameStats({
    required this.xp,
    required this.currentStreak,
    required this.bestStreak,
    required this.checkedInToday,
    required this.questsDoneToday,
    required this.xpToday,
    required this.badges,
  });

  factory GameStats.fromMap(Map<String, dynamic> m) => GameStats(
        xp: (m['xp'] ?? 0) as int,
        currentStreak: (m['current_streak'] ?? 0) as int,
        bestStreak: (m['best_streak'] ?? 0) as int,
        checkedInToday: (m['checked_in_today'] ?? false) as bool,
        questsDoneToday: Set<String>.from((m['quests_done_today'] ?? []) as List),
        xpToday: (m['xp_today'] ?? 0) as int,
        badges: Set<String>.from((m['badges'] ?? []) as List),
      );
}

class XpResult {
  final int gained;
  final int xp;
  final List<String> newBadges;
  XpResult(this.gained, this.xp, this.newBadges);
  factory XpResult.fromMap(Map<String, dynamic> m) => XpResult(
        (m['gained'] ?? 0) as int,
        (m['xp'] ?? 0) as int,
        List<String>.from((m['new_badges'] ?? []) as List),
      );
}

class QuestEntry {
  final String? note;
  final String? photoUrl;
  QuestEntry(this.note, this.photoUrl);
}

class AppBadge {
  final String key, name, emoji, description;
  AppBadge(this.key, this.name, this.emoji, this.description);
}

class XpEvent {
  final String source;
  final int points;
  final DateTime createdAt;
  XpEvent(this.source, this.points, this.createdAt);
}

class GameService {
  static Future<GameStats> stats() async {
    final res = await supa.rpc('my_stats');
    return GameStats.fromMap(Map<String, dynamic>.from(res as Map));
  }

  static Future<XpResult> checkIn() async {
    final res = await supa.rpc('daily_checkin');
    return XpResult.fromMap(Map<String, dynamic>.from(res as Map));
  }

  /// Completes a quest with proof: a written note and/or a photo.
  static Future<XpResult> completeQuest(
    String key, {
    String? note,
    Uint8List? photoBytes,
    String? photoExt,
  }) async {
    String? path;
    if (photoBytes != null) {
      final uid = supa.auth.currentUser!.id;
      final ext = (photoExt ?? 'jpg').toLowerCase();
      path = '$uid/${dateKey(DateTime.now())}_${key}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await supa.storage.from('quest-proofs').uploadBinary(
            path,
            photoBytes,
            fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg', upsert: true),
          );
    }
    final res = await supa.rpc('complete_quest', params: {
      'p_key': key,
      'p_note': note,
      'p_photo_path': path,
    });
    return XpResult.fromMap(Map<String, dynamic>.from(res as Map));
  }

  static Future<QuestEntry?> questEntry(String key) async {
    final row = await supa
        .from('quest_entries')
        .select()
        .eq('quest_key', key)
        .eq('day', dateKey(lagosToday()))
        .maybeSingle();
    if (row == null) return null;
    String? url;
    if (row['photo_path'] != null) {
      url = await supa.storage.from('quest-proofs').createSignedUrl(row['photo_path'] as String, 3600);
    }
    return QuestEntry(row['note'] as String?, url);
  }

  static List<AppBadge>? _badgeCache;
  static Future<List<AppBadge>> allBadges() async {
    if (_badgeCache != null) return _badgeCache!;
    final rows = await supa.from('badges').select().order('sort');
    _badgeCache = rows
        .map<AppBadge>((r) => AppBadge(r['key'], r['name'], r['emoji'], r['description']))
        .toList();
    return _badgeCache!;
  }

  static Future<List<XpEvent>> recentXp() async {
    final rows = await supa
        .from('xp_events')
        .select('source, points, created_at')
        .order('created_at', ascending: false)
        .limit(30);
    return rows
        .map<XpEvent>((r) => XpEvent(
              r['source'] as String,
              r['points'] as int,
              DateTime.parse(r['created_at'] as String).toLocal(),
            ))
        .toList();
  }
}
