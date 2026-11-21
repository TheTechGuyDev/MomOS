import 'package:supabase_flutter/supabase_flutter.dart';

final supa = Supabase.instance.client;

class Profile {
  final String id;
  final String displayName;
  final String role;
  final String? familyId;
  final String avatar;
  final int xp;

  Profile({
    required this.id,
    required this.displayName,
    required this.role,
    required this.familyId,
    required this.avatar,
    required this.xp,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        displayName: (m['display_name'] ?? 'Me') as String,
        role: (m['role'] ?? 'mom') as String,
        familyId: m['family_id'] as String?,
        avatar: (m['avatar_emoji'] ?? '🌸') as String,
        xp: (m['xp'] ?? 0) as int,
      );
}

class Family {
  final String id;
  final String name;
  final String inviteCode;
  Family({required this.id, required this.name, required this.inviteCode});
  factory Family.fromMap(Map<String, dynamic> m) => Family(
        id: m['id'] as String,
        name: m['name'] as String,
        inviteCode: m['invite_code'] as String,
      );
}

class ProfileService {
  static Future<Profile?> me() async {
    final uid = supa.auth.currentUser?.id;
    if (uid == null) return null;
    final row =
        await supa.from('profiles').select().eq('id', uid).maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  static Future<Family?> myFamily(String? familyId) async {
    if (familyId == null) return null;
    final row =
        await supa.from('families').select().eq('id', familyId).maybeSingle();
    return row == null ? null : Family.fromMap(row);
  }

  static Future<List<Profile>> familyMembers(String familyId) async {
    final rows = await supa.from('profiles').select().eq('family_id', familyId);
    return rows.map<Profile>((r) => Profile.fromMap(r)).toList();
  }

  static Future<void> createFamily(String name) =>
      supa.rpc('create_family', params: {'p_name': name});

  static Future<void> joinFamily(String code) =>
      supa.rpc('join_family', params: {'p_code': code});
}
