import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_service.dart';

/// Cached facts about the signed-in user, plus media helpers.
class AppSession {
  static String? _familyId;
  static String? _userId;
  static final Map<String, (String, DateTime)> _urlCache = {};

  static String get uid => supa.auth.currentUser!.id;

  static Future<String> familyId() async {
    if (_familyId != null && _userId == uid) return _familyId!;
    final p = await ProfileService.me();
    _familyId = p!.familyId!;
    _userId = uid;
    return _familyId!;
  }

  static void clear() {
    _familyId = null;
    _userId = null;
    _urlCache.clear();
  }

  static String contentTypeFor(String ext) {
    switch (ext.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'webm':
        return 'audio/webm';
      case 'm4a':
      case 'mp4':
        return 'audio/mp4';
      case 'ogg':
        return 'audio/ogg';
      default:
        return 'image/jpeg';
    }
  }

  static Future<String> upload(String bucket, String path, Uint8List bytes, String ext) async {
    await supa.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentTypeFor(ext), upsert: true),
        );
    return path;
  }

  /// Signed URL, cached for 50 minutes.
  static Future<String> signedUrl(String bucket, String path) async {
    final key = '$bucket/$path';
    final hit = _urlCache[key];
    if (hit != null && DateTime.now().isBefore(hit.$2)) return hit.$1;
    final url = await supa.storage.from(bucket).createSignedUrl(path, 3600);
    _urlCache[key] = (url, DateTime.now().add(const Duration(minutes: 50)));
    return url;
  }
}
