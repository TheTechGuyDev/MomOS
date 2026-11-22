import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'profile_service.dart';

/// Offline support:
/// - read results are cached on the phone and shown when there's no internet
/// - writes made offline are queued and sent when the connection returns
class Offline {
  static const _cachePrefix = 'momos_cache_';
  static const _outboxKey = 'momos_outbox';
  static final online = ValueNotifier<bool>(true);
  static final pending = ValueNotifier<int>(0);
  static Timer? _timer;
  static bool _flushing = false;

  static void start() {
    online.value = web.window.navigator.onLine;
    pending.value = _outbox().length;
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) => flush());
    web.window.addEventListener('online', ((web.Event _) {
      online.value = true;
      flush();
    }).toJS);
    web.window.addEventListener('offline', ((web.Event _) => online.value = false).toJS);
    flush();
  }

  static String? _get(String k) {
    try {
      return web.window.localStorage.getItem(k);
    } catch (_) {
      return null;
    }
  }

  static void _set(String k, String v) {
    try {
      web.window.localStorage.setItem(k, v);
    } catch (_) {}
  }

  /// Network first; on failure use the last saved copy.
  static Future<List<Map<String, dynamic>>> cachedList(
    String key,
    Future<List<Map<String, dynamic>>> Function() fetch,
  ) async {
    final k = '$_cachePrefix${supa.auth.currentUser?.id}_$key';
    try {
      final rows = await fetch();
      online.value = true;
      _set(k, jsonEncode(rows));
      return rows;
    } catch (e) {
      final c = _get(k);
      if (c != null) {
        online.value = false;
        return (jsonDecode(c) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      rethrow;
    }
  }

  static List<Map<String, dynamic>> _outbox() {
    final raw = _get(_outboxKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static void _saveOutbox(List<Map<String, dynamic>> box) {
    _set(_outboxKey, jsonEncode(box));
    pending.value = box.length;
  }

  static Future<void> _send(Map<String, dynamic> op) async {
    final table = op['table'] as String;
    final data = Map<String, dynamic>.from(op['data'] as Map);
    switch (op['op']) {
      case 'insert':
        await supa.from(table).insert(data);
      case 'update':
        await supa.from(table).update(data).eq('id', op['id'] as String);
      case 'delete':
        await supa.from(table).delete().eq('id', op['id'] as String);
    }
  }

  /// Try to write now; if the network fails, queue it.
  static Future<void> write(String table, String op, Map<String, dynamic> data, {String? id}) async {
    final item = {'table': table, 'op': op, 'data': data, 'id': ?id};
    try {
      await _send(item);
      online.value = true;
    } catch (e) {
      final msg = '$e'.toLowerCase();
      final network = msg.contains('failed to fetch') || msg.contains('network') || msg.contains('socket') || !web.window.navigator.onLine;
      if (!network) rethrow;
      online.value = false;
      _saveOutbox([..._outbox(), item]);
    }
  }

  static Future<void> flush() async {
    if (_flushing) return;
    final box = _outbox();
    if (box.isEmpty) return;
    _flushing = true;
    final left = <Map<String, dynamic>>[];
    for (var i = 0; i < box.length; i++) {
      try {
        await _send(box[i]);
      } catch (e) {
        final msg = '$e'.toLowerCase();
        if (msg.contains('failed to fetch') || msg.contains('network')) {
          left.addAll(box.sublist(i));
          break;
        }
        // a real error (e.g. deleted row): drop it so the queue doesn't get stuck
      }
    }
    _saveOutbox(left);
    if (left.isEmpty) online.value = true;
    _flushing = false;
  }
}
