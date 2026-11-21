import 'app_events.dart';
import 'profile_service.dart';
import 'session.dart';
import 'time_utils.dart';

class FamilyEvent {
  final String id;
  final String title;
  final DateTime startsAt;
  final bool allDay;
  final String? location;
  final String? notes;
  final String emoji;
  FamilyEvent(this.id, this.title, this.startsAt, this.allDay, this.location, this.notes, this.emoji);

  factory FamilyEvent.fromMap(Map<String, dynamic> m) => FamilyEvent(
        m['id'] as String,
        m['title'] as String,
        DateTime.parse(m['starts_at'] as String).toLocal(),
        (m['all_day'] ?? false) as bool,
        m['location'] as String?,
        m['notes'] as String?,
        (m['emoji'] ?? '📅') as String,
      );
}

class Chore {
  final String id;
  final String title;
  final String? assignee;
  final DateTime? dueDate;
  final String repeat;
  final bool done;
  final String? doneBy;
  Chore(this.id, this.title, this.assignee, this.dueDate, this.repeat, this.done, this.doneBy);

  factory Chore.fromMap(Map<String, dynamic> m) => Chore(
        m['id'] as String,
        m['title'] as String,
        m['assignee'] as String?,
        m['due_date'] == null ? null : DateTime.parse(m['due_date'] as String),
        (m['repeat'] ?? 'none') as String,
        (m['done'] ?? false) as bool,
        m['done_by'] as String?,
      );
}

class ShoppingItem {
  final String id;
  final String name;
  final String? qty;
  final String category;
  final bool checked;
  ShoppingItem(this.id, this.name, this.qty, this.category, this.checked);

  factory ShoppingItem.fromMap(Map<String, dynamic> m) => ShoppingItem(
        m['id'] as String,
        m['name'] as String,
        m['qty'] as String?,
        (m['category'] ?? 'other') as String,
        (m['checked'] ?? false) as bool,
      );
}

const shoppingCategories = <(String, String)>[
  ('baby', '🍼 Baby'),
  ('food', '🥘 Food'),
  ('household', '🧽 Household'),
  ('health', '💊 Health'),
  ('school', '🎒 School'),
  ('other', '🛒 Other'),
];

class FamilyService {
  // Calendar
  static Future<List<FamilyEvent>> events({DateTime? from}) async {
    final start = from ?? DateTime.now().subtract(const Duration(days: 1));
    final rows = await supa
        .from('family_events')
        .select()
        .gte('starts_at', start.toUtc().toIso8601String())
        .order('starts_at')
        .limit(300);
    return rows.map<FamilyEvent>((r) => FamilyEvent.fromMap(r)).toList();
  }

  static Future<void> saveEvent({
    String? id,
    required String title,
    required DateTime startsAt,
    bool allDay = false,
    String? location,
    String? notes,
    String emoji = '📅',
  }) async {
    final data = {
      'title': title.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'all_day': allDay,
      'location': (location ?? '').trim().isEmpty ? null : location!.trim(),
      'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
      'emoji': emoji,
    };
    if (id == null) {
      await supa.from('family_events').insert({...data, 'family_id': await AppSession.familyId()});
    } else {
      await supa.from('family_events').update(data).eq('id', id);
    }
  }

  static Future<void> deleteEvent(String id) => supa.from('family_events').delete().eq('id', id);

  // Chores
  static Future<List<Chore>> chores() async {
    final rows = await supa.from('chores').select().order('done').order('due_date', nullsFirst: false).limit(300);
    return rows.map<Chore>((r) => Chore.fromMap(r)).toList();
  }

  static Future<void> saveChore({
    String? id,
    required String title,
    String? assignee,
    DateTime? dueDate,
    String repeat = 'none',
  }) async {
    final data = {
      'title': title.trim(),
      'assignee': assignee,
      'due_date': dueDate == null ? null : dateKey(dueDate),
      'repeat': repeat,
    };
    if (id == null) {
      await supa.from('chores').insert({...data, 'family_id': await AppSession.familyId()});
    } else {
      await supa.from('chores').update(data).eq('id', id);
    }
  }

  static Future<void> setChoreDone(String id, bool done) async {
    await supa.from('chores').update({'done': done}).eq('id', id);
    if (done) AppEvents.bump();
  }

  static Future<void> deleteChore(String id) => supa.from('chores').delete().eq('id', id);

  // Shopping
  static Future<List<ShoppingItem>> shopping() async {
    final rows = await supa.from('shopping_items').select().order('checked').order('created_at', ascending: false).limit(500);
    return rows.map<ShoppingItem>((r) => ShoppingItem.fromMap(r)).toList();
  }

  static Future<void> addItem(String name, String? qty, String category) async {
    await supa.from('shopping_items').insert({
      'name': name.trim(),
      'qty': (qty ?? '').trim().isEmpty ? null : qty!.trim(),
      'category': category,
      'family_id': await AppSession.familyId(),
    });
  }

  static Future<void> setChecked(String id, bool checked) =>
      supa.from('shopping_items').update({'checked': checked}).eq('id', id);

  static Future<void> deleteItem(String id) => supa.from('shopping_items').delete().eq('id', id);

  static Future<void> clearChecked() async {
    await supa.from('shopping_items').delete().eq('checked', true).eq('family_id', await AppSession.familyId());
  }
}
