import 'dart:typed_data';

import 'app_events.dart';
import 'offline.dart';
import 'profile_service.dart';
import 'session.dart';
import 'time_utils.dart';

typedef Rec = Map<String, dynamic>;

/// Simple data access for the life-manager modules. Reads are cached for offline use.
class Life {
  static Future<List<Rec>> list(
    String table, {
    Map<String, Object?> eq = const {},
    String? order,
    bool ascending = true,
    int limit = 500,
    String select = '*',
  }) async {
    final cacheKey = 'list:$table:${eq.toString()}:$order:$ascending:$limit';
    return Offline.cachedList(cacheKey, () async {
      var q = supa.from(table).select(select);
      eq.forEach((k, v) {
        q = v == null ? q.isFilter(k, null) : q.eq(k, v);
      });
      final rows = order == null
          ? await q.limit(limit)
          : await q.order(order, ascending: ascending, nullsFirst: false).limit(limit);
      return rows.map<Rec>((r) => Map<String, dynamic>.from(r)).toList();
    });
  }

  /// Inserts a row. Family tables get family_id automatically. Queued if offline.
  static Future<void> insert(String table, Rec data, {bool family = true, bool xp = false}) async {
    final row = {...data};
    if (family) row['family_id'] = await AppSession.familyId();
    await Offline.write(table, 'insert', row);
    if (xp) AppEvents.bump();
  }

  static Future<void> update(String table, String id, Rec data) => Offline.write(table, 'update', data, id: id);

  static Future<void> delete(String table, String id) => Offline.write(table, 'delete', const {}, id: id);

  static Future<dynamic> rpc(String fn, [Map<String, dynamic>? params]) async {
    final r = await supa.rpc(fn, params: params);
    AppEvents.bump();
    return r;
  }

  static Future<String> uploadPrivate(Uint8List bytes, String ext, String folder) => AppSession.upload(
        'private-media',
        '${AppSession.uid}/$folder/${DateTime.now().millisecondsSinceEpoch}.$ext',
        bytes,
        ext,
      );

  static Future<String> uploadFamily(Uint8List bytes, String ext, String folder) async {
    final fam = await AppSession.familyId();
    return AppSession.upload('memory-media', 'family/$fam/$folder/${DateTime.now().millisecondsSinceEpoch}.$ext', bytes, ext);
  }

  static String d(DateTime v) => dateKey(v);
  static DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
}
