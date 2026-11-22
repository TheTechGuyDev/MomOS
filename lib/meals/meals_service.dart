import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../core/family_service.dart';
import '../core/profile_service.dart';
import '../core/session.dart';
import '../core/time_utils.dart';
import 'dishes.dart';

/// plan[dayIndex 0-6 as string][slot 'b'|'l'|'d'] = dish key
typedef MealPlan = Map<String, Map<String, String>>;

class MealsService {
  static DateTime weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  static Future<MealPlan?> load(DateTime week) async {
    final row = await supa.from('meal_plans').select('plan').eq('week_start', dateKey(week)).maybeSingle();
    if (row == null) return null;
    final raw = Map<String, dynamic>.from(row['plan'] as Map);
    return raw.map((k, v) => MapEntry(k, Map<String, String>.from(v as Map)));
  }

  static Future<void> save(DateTime week, MealPlan plan) async {
    await supa.from('meal_plans').upsert({
      'family_id': await AppSession.familyId(),
      'week_start': dateKey(week),
      'plan': plan,
    });
  }

  /// Builds a varied week: no dish twice within 3 days, quick breakfasts on weekdays.
  static MealPlan generate({int? seed}) {
    final rnd = Random(seed);
    final plan = <String, Map<String, String>>{};
    final recent = <String>[];
    for (var day = 0; day < 7; day++) {
      final today = <String, String>{};
      for (final slot in ['b', 'l', 'd']) {
        var pool = dishes.where((d) => d.slots.contains(slot) && !recent.contains(d.key) && !today.containsValue(d.key)).toList();
        if (slot == 'b' && day < 5) {
          final quick = pool.where((d) => d.minutes <= 40).toList();
          if (quick.length >= 2) pool = quick;
        }
        if (pool.isEmpty) pool = dishes.where((d) => d.slots.contains(slot)).toList();
        final pick = pool[rnd.nextInt(pool.length)];
        today[slot] = pick.key;
        recent.add(pick.key);
      }
      while (recent.length > 9) {
        recent.removeAt(0);
      }
      plan['$day'] = today;
    }
    return plan;
  }

  static Future<int> addToShopping(Dish d) async {
    for (final i in d.ingredients) {
      await FamilyService.addItem(i, null, 'food');
    }
    return d.ingredients.length;
  }

  // ---------- Photos from Wikipedia (cached on the phone) ----------
  static final Map<String, String?> _photos = {};
  static Future<void>? _loading;

  static Future<String?> photoFor(Dish d) async {
    if (_photos.containsKey(d.wiki)) return _photos[d.wiki];
    _loading ??= _loadAll();
    await _loading;
    return _photos[d.wiki];
  }

  static Future<void> _loadAll() async {
    const cacheKey = 'momos_dish_photos_v1';
    try {
      final cached = web.window.localStorage.getItem(cacheKey);
      if (cached != null) {
        final m = Map<String, dynamic>.from(jsonDecode(cached) as Map);
        m.forEach((k, v) => _photos[k] = v as String?);
        if (dishes.every((d) => _photos.containsKey(d.wiki))) return;
      }
    } catch (_) {}

    final titles = dishes.map((d) => d.wiki).toSet().toList();
    for (var i = 0; i < titles.length; i += 40) {
      final batch = titles.sublist(i, min(i + 40, titles.length));
      try {
        final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
          'action': 'query',
          'format': 'json',
          'origin': '*',
          'redirects': '1',
          'prop': 'pageimages',
          'piprop': 'thumbnail',
          'pithumbsize': '480',
          'titles': batch.join('|'),
        });
        final res = await http.get(uri);
        final q = (jsonDecode(res.body) as Map)['query'] as Map? ?? {};
        // Map normalised/redirected titles back to what we asked for
        final back = <String, String>{for (final t in batch) t: t};
        for (final key in ['normalized', 'redirects']) {
          for (final m in (q[key] as List? ?? [])) {
            final from = m['from'] as String, to = m['to'] as String;
            final orig = back.entries.where((e) => e.value == from).map((e) => e.key).toList();
            for (final o in orig) {
              back[o] = to;
            }
          }
        }
        final byTitle = <String, String?>{};
        for (final p in (q['pages'] as Map? ?? {}).values) {
          byTitle[p['title'] as String] = (p['thumbnail'] as Map?)?['source'] as String?;
        }
        for (final t in batch) {
          _photos[t] = byTitle[back[t]];
        }
      } catch (_) {}
    }
    try {
      web.window.localStorage.setItem(cacheKey, jsonEncode(_photos));
    } catch (_) {}
  }
}
