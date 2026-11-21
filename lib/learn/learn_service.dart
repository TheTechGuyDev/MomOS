import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_events.dart';
import '../core/profile_service.dart';

class LessonProgress {
  final String key;
  final int bestScore;
  final int total;
  final DateTime completedAt;
  LessonProgress(this.key, this.bestScore, this.total, this.completedAt);
}

class LessonResult {
  final int gained;
  final bool firstTime;
  final String? trackCompleted;
  final List<String> newBadges;
  LessonResult(this.gained, this.firstTime, this.trackCompleted, this.newBadges);
}

class PortfolioProject {
  final String id;
  final String title;
  final String? description;
  final List<String> tools;
  final String? link;
  final DateTime createdAt;
  PortfolioProject(this.id, this.title, this.description, this.tools, this.link, this.createdAt);

  factory PortfolioProject.fromMap(Map<String, dynamic> m) => PortfolioProject(
        m['id'] as String,
        m['title'] as String,
        m['description'] as String?,
        List<String>.from((m['tools'] ?? []) as List),
        m['link'] as String?,
        DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

class TutorMessage {
  final String role; // 'user' or 'assistant'
  final String text;
  TutorMessage(this.role, this.text);
  Map<String, String> toJson() => {'role': role, 'content': text};
}

class LearnService {
  static Future<Map<String, LessonProgress>> progress() async {
    final rows = await supa.from('lesson_progress').select();
    return {
      for (final r in rows)
        r['lesson_key'] as String: LessonProgress(
          r['lesson_key'] as String,
          r['best_score'] as int,
          r['total'] as int,
          DateTime.parse(r['completed_at'] as String).toLocal(),
        ),
    };
  }

  static Future<LessonResult> completeLesson(String key, int score, int total) async {
    final r = Map<String, dynamic>.from(
      await supa.rpc('complete_lesson', params: {'p_key': key, 'p_score': score, 'p_total': total}) as Map,
    );
    final gained = (r['gained'] ?? 0) as int;
    if (gained > 0) AppEvents.bump();
    return LessonResult(
      gained,
      (r['first_time'] ?? false) as bool,
      r['track_completed'] as String?,
      List<String>.from((r['new_badges'] ?? []) as List),
    );
  }

  /// Consecutive days (ending today or yesterday) with at least one lesson finished.
  static int learningStreak(Iterable<LessonProgress> items) {
    final days = items.map((p) => DateTime(p.completedAt.year, p.completedAt.month, p.completedAt.day)).toSet();
    final now = DateTime.now();
    var d = DateTime(now.year, now.month, now.day);
    if (!days.contains(d)) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days.contains(d)) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  // SQL Lab
  static Future<List<Map<String, dynamic>>> runSql(String q) async {
    final r = await supa.rpc('run_sandbox_sql', params: {'q': q});
    final list = r is String ? jsonDecode(r) as List : r as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // Portfolio
  static Future<List<PortfolioProject>> portfolio() async {
    final rows = await supa.from('portfolio_projects').select().order('created_at', ascending: false);
    return rows.map<PortfolioProject>((r) => PortfolioProject.fromMap(r)).toList();
  }

  static Future<void> saveProject({String? id, required String title, String? description, List<String> tools = const [], String? link}) async {
    final data = {
      'title': title.trim(),
      'description': (description ?? '').trim().isEmpty ? null : description!.trim(),
      'tools': tools,
      'link': (link ?? '').trim().isEmpty ? null : link!.trim(),
    };
    if (id == null) {
      await supa.from('portfolio_projects').insert(data);
    } else {
      await supa.from('portfolio_projects').update(data).eq('id', id);
    }
  }

  static Future<void> deleteProject(String id) => supa.from('portfolio_projects').delete().eq('id', id);

  // AI tutor (Supabase Edge Function)
  static Future<String> askTutor(List<TutorMessage> history, {String? lessonTitle}) async {
    try {
      final res = await supa.functions.invoke('ai-tutor', body: {
        'messages': history.map((m) => m.toJson()).toList(),
        'lesson': ?lessonTitle,
      });
      final data = res.data is String ? jsonDecode(res.data as String) : res.data;
      return (data['reply'] ?? 'Sorry, I could not answer that.') as String;
    } on FunctionException catch (e) {
      final d = e.details;
      if (d is Map && d['error'] != null) throw Exception(d['error']);
      throw Exception('The tutor is not available right now.');
    }
  }
}
