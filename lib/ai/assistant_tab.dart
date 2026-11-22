import 'dart:convert';
import 'dart:js_interop';

import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

import '../core/family_service.dart';
import '../core/kids_service.dart';
import '../core/life_service.dart';
import '../core/memory_service.dart';
import '../core/profile_service.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../meals/meals_service.dart';
import '../widgets/form_sheet.dart';
import '../widgets/ui.dart';

@JS('momosSpeechSupported')
external JSBoolean _speechSupported();
@JS('momosListen')
external JSPromise<JSString> _listen(JSString lang);
@JS('momosStopListening')
external void _stopListening();
@JS('momosSpeak')
external void _speak(JSString text);
@JS('momosStopSpeaking')
external void _stopSpeaking();

class _Msg {
  final String role;
  final String text;
  final List<Map<String, dynamic>> actions;
  final Set<int> done;
  _Msg(this.role, this.text, [this.actions = const []]) : done = {};
  Map<String, dynamic> toJson() => {'role': role, 'text': text, 'actions': actions, 'done': done.toList()};
  static _Msg fromJson(Map<String, dynamic> m) {
    final x = _Msg(m['role'] as String, m['text'] as String, List<Map<String, dynamic>>.from(((m['actions'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map))));
    x.done.addAll(List<int>.from((m['done'] ?? []) as List));
    return x;
  }
}

/// HerAssistant: chat by text or voice; it proposes actions she can add with one tap.
class AssistantTab extends StatefulWidget {
  const AssistantTab({super.key});
  @override
  State<AssistantTab> createState() => _AssistantTabState();
}

class _AssistantTabState extends State<AssistantTab> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  List<_Msg> _msgs = [];
  bool _thinking = false;
  bool _listening = false;
  bool _speakReplies = false;

  String get _storeKey => 'momos_assistant_${AppSession.uid}';

  static const _examples = [
    'Plan my meals for next week',
    'Remind me to buy cooking gas tomorrow',
    'What household activities do I have today?',
    'Create a shopping list for this weekend',
    'I have visitors tomorrow. Help me prepare',
    'I have ₦50,000 for groceries. Help me plan',
    'Organise my children\'s activities for next week',
  ];

  bool get _voiceOk {
    try {
      return _speechSupported().toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    try {
      final raw = web.window.localStorage.getItem(_storeKey);
      if (raw != null) {
        _msgs = (jsonDecode(raw) as List).map((e) => _Msg.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
  }

  void _save() {
    try {
      final keep = _msgs.length > 40 ? _msgs.sublist(_msgs.length - 40) : _msgs;
      web.window.localStorage.setItem(_storeKey, jsonEncode(keep.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent + 300, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _c.text).trim();
    if (text.isEmpty || _thinking) return;
    _c.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _msgs.add(_Msg('user', text));
      _thinking = true;
    });
    _toBottom();
    try {
      final history = _msgs.where((m) => !m.text.startsWith('⚠️')).toList();
      final recent = history.length > 14 ? history.sublist(history.length - 14) : history;
      final r = await supa.functions.invoke('assistant', body: {
        'mode': 'chat',
        'messages': recent.map((m) => {'role': m.role, 'content': m.text}).toList(),
      });
      final d = r.data is String ? jsonDecode(r.data as String) : r.data;
      final reply = (d['reply'] ?? '') as String;
      final actions = List<Map<String, dynamic>>.from(((d['actions'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)));
      setState(() => _msgs.add(_Msg('assistant', reply, actions)));
      if (_speakReplies && reply.isNotEmpty) _speak(reply.toJS);
    } catch (e) {
      setState(() => _msgs.add(_Msg('assistant', '⚠️ I couldn\'t answer just now. Please try again.')));
    } finally {
      setState(() => _thinking = false);
      _save();
      _toBottom();
    }
  }

  Future<void> _voice() async {
    if (_listening) {
      try {
        _stopListening();
      } catch (_) {}
      return;
    }
    setState(() => _listening = true);
    try {
      final t = (await _listen('en-NG'.toJS).toDart).toDart;
      if (t.startsWith('error:')) {
        if (mounted) {
          toast(context, t.contains('not-allowed') ? 'Please allow the microphone for this site.' : 'I didn\'t catch that. Try again or type.');
        }
      } else if (t.trim().isNotEmpty) {
        await _send(t);
      }
    } catch (_) {
      if (mounted) toast(context, 'Voice isn\'t available in this browser. You can type instead.');
    } finally {
      if (mounted) setState(() => _listening = false);
    }
  }

  // ---------- action execution (only after she taps Add) ----------
  String _describe(Map<String, dynamic> a) {
    DateTime? dt(String k) => a[k] == null ? null : DateTime.tryParse('${a[k]}')?.toLocal();
    String when(DateTime? d) => d == null ? '' : (isSameDay(d, DateTime.now()) ? 'Today ${clock(d)}' : '${shortDate(d)}, ${clock(d)}');
    switch (a['type']) {
      case 'reminder':
        return '🔔 Reminder: ${a['title']}\n${when(dt('due_at'))}${a['level'] != null && a['level'] != 'gentle' ? ' · ${a['level']}' : ''}${a['repeat'] != null && a['repeat'] != 'none' ? ' · ${a['repeat']}' : ''}';
      case 'shopping':
        final items = List<Map<String, dynamic>>.from(((a['items'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)));
        return '🛒 Add to shopping list:\n${items.map((i) => '• ${i['name']}${(i['qty'] ?? '').toString().isNotEmpty ? ' (${i['qty']})' : ''}').join('\n')}';
      case 'event':
        return '📅 Calendar: ${a['title']}\n${a['all_day'] == true ? shortDate(dt('starts_at') ?? DateTime.now()) : when(dt('starts_at'))}${a['location'] != null && '${a['location']}'.isNotEmpty ? ' · ${a['location']}' : ''}';
      case 'household':
        return '🧹 Household job: ${a['title']}\n${a['frequency']} · from ${a['next_due']}';
      case 'school':
        return '🎒 ${a['child']}: ${a['title']}\n${a['category']} · ${a['due_date'] ?? ''}';
      case 'expense':
        return '💸 Expense: ${naira(num.tryParse('${a['amount']}') ?? 0)} · ${a['category']}${a['note'] != null ? '\n${a['note']}' : ''}';
      case 'goal':
        return '🎯 Goal: ${a['title']} (${a['period']})';
      case 'plan_meals':
        return '🍲 Make a meal plan for ${a['week'] == 'next' ? 'next week' : 'this week'}';
      case 'pantry':
        final items = List<Map<String, dynamic>>.from(((a['items'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)));
        return '🥫 Add to pantry: ${items.map((i) => i['name']).join(', ')}';
    }
    return '${a['type']}';
  }

  Future<void> _run(Map<String, dynamic> a) async {
    switch (a['type']) {
      case 'reminder':
        await MemoryService.saveReminder(
          title: '${a['title']}',
          notes: a['notes'] as String?,
          dueAt: DateTime.tryParse('${a['due_at']}')?.toLocal(),
          repeat: ['none', 'daily', 'weekly', 'monthly'].contains(a['repeat']) ? a['repeat'] as String : 'none',
          level: ['gentle', 'important', 'alarm'].contains(a['level']) ? a['level'] as String : 'gentle',
        );
      case 'shopping':
        for (final i in (a['items'] ?? []) as List) {
          final m = Map<String, dynamic>.from(i as Map);
          final cat = shoppingCategories.any((c) => c.$1 == m['category']) ? m['category'] as String : 'other';
          await FamilyService.addItem('${m['name']}', (m['qty'] ?? '').toString(), cat);
        }
      case 'event':
        await FamilyService.saveEvent(
          title: '${a['title']}',
          startsAt: DateTime.tryParse('${a['starts_at']}')?.toLocal() ?? DateTime.now(),
          allDay: a['all_day'] == true,
          location: a['location'] as String?,
        );
      case 'household':
        await Life.insert('household_tasks', {
          'title': a['title'],
          'emoji': '🧹',
          'frequency': ['daily', 'weekly', 'monthly', 'once'].contains(a['frequency']) ? a['frequency'] : 'once',
          'next_due': '${a['next_due'] ?? dateKey(DateTime.now())}',
        });
      case 'school':
        final kids = await KidsService.children();
        final child = kids.where((k) => k.name.toLowerCase() == '${a['child']}'.toLowerCase()).firstOrNull ?? kids.where((k) => !k.isBaby).firstOrNull ?? kids.firstOrNull;
        if (child == null) throw Exception('Add your children in Family → Kids first.');
        const cats = ['homework', 'school_event', 'activity', 'exam', 'supplies', 'medical', 'other'];
        await KidsService.addTask(child.id, '${a['title']}', cats.contains(a['category']) ? a['category'] as String : 'other', DateTime.tryParse('${a['due_date']}'));
      case 'expense':
        await Life.insert('transactions', {
          'kind': 'expense',
          'amount': num.tryParse('${a['amount']}') ?? 0,
          'category': a['category'] ?? 'other',
          'note': a['note'],
        }, xp: true);
      case 'goal':
        await Life.insert('goals', {'title': a['title'], 'period': ['daily', 'weekly', 'once'].contains(a['period']) ? a['period'] : 'once'});
      case 'plan_meals':
        var week = MealsService.weekStart(DateTime.now());
        if (a['week'] == 'next') week = week.add(const Duration(days: 7));
        Set<String> avoid = {};
        try {
          final p = await supa.from('food_prefs').select('dislikes,allergies').maybeSingle();
          avoid = {...List<String>.from((p?['dislikes'] ?? []) as List), ...List<String>.from((p?['allergies'] ?? []) as List)};
        } catch (_) {}
        await MealsService.save(week, MealsService.generate(seed: DateTime.now().millisecondsSinceEpoch, avoid: avoid));
      case 'pantry':
        for (final i in (a['items'] ?? []) as List) {
          final m = Map<String, dynamic>.from(i as Map);
          await Life.insert('inventory_items', {
            'name': m['name'],
            'qty': num.tryParse('${m['qty']}') ?? 1,
            'unit': m['unit'],
            'place': ['kitchen', 'fridge', 'freezer'].contains(m['place']) ? m['place'] : 'kitchen',
          });
        }
      default:
        throw Exception('Unknown action');
    }
  }

  Future<void> _apply(_Msg m, int i) async {
    try {
      await _run(m.actions[i]);
      setState(() => m.done.add(i));
      _save();
      if (mounted) toast(context, 'Added ✅');
    } catch (e) {
      if (mounted) toast(context, '$e'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      TabHeader(
        title: 'HerAssistant',
        subtitle: 'Ask by voice or text. Nothing is saved until you tap Add',
        action: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: _speakReplies ? 'Stop reading replies aloud' : 'Read replies aloud',
            icon: Icon(_speakReplies ? Icons.volume_up : Icons.volume_off_outlined),
            onPressed: () {
              setState(() => _speakReplies = !_speakReplies);
              if (!_speakReplies) {
                try {
                  _stopSpeaking();
                } catch (_) {}
              }
            },
          ),
          if (_msgs.isNotEmpty)
            IconButton(
              tooltip: 'New conversation',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {
                _msgs = [];
                _save();
              }),
            ),
        ]),
      ),
      Expanded(
        child: ListView(controller: _scroll, padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
          if (_msgs.isEmpty) ...[
            const SizedBox(height: 10),
            const Center(child: Text('✨', style: TextStyle(fontSize: 52))),
            const SizedBox(height: 6),
            Text('Hi! How can I help today?', textAlign: TextAlign.center, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            Text('I can plan, remind, make lists and organise things for you.', textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 16),
            ..._examples.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.all(14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _send(e),
                    child: Text('"$e"'),
                  ),
                )),
          ],
          ..._msgs.map((m) {
            final me = m.role == 'user';
            return Column(crossAxisAlignment: me ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.84),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: me ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(me ? 18 : 4),
                    bottomRight: Radius.circular(me ? 4 : 18),
                  ),
                ),
                child: SelectableText(m.text, style: TextStyle(color: me ? Colors.white : AppColors.ink, height: 1.4)),
              ),
              if (m.actions.isNotEmpty) ...[
                ...m.actions.asMap().entries.map((e) {
                  final done = m.done.contains(e.key);
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    decoration: BoxDecoration(
                      color: done ? AppColors.mint.withValues(alpha: 0.12) : AppColors.secondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: done ? AppColors.mint : AppColors.secondary.withValues(alpha: 0.3)),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(_describe(e.value), style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35))),
                      done
                          ? const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.check_circle, color: AppColors.mint))
                          : FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
                              onPressed: () => _apply(m, e.key),
                              child: const Text('Add'),
                            ),
                    ]),
                  );
                }),
                if (m.actions.length > 1 && m.done.length < m.actions.length)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        for (var i = 0; i < m.actions.length; i++) {
                          if (!m.done.contains(i)) await _apply(m, i);
                        }
                      },
                      icon: const Icon(Icons.done_all),
                      label: const Text('Add all'),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            ]);
          }),
          if (_thinking)
            const Padding(padding: EdgeInsets.all(8), child: Text('Thinking…', style: TextStyle(color: AppColors.muted))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(children: [
          if (_voiceOk)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: _listening ? Colors.red.shade400 : AppColors.secondary, minimumSize: const Size(52, 52)),
                tooltip: _listening ? 'Stop' : 'Speak',
                onPressed: _thinking ? null : _voice,
                icon: Icon(_listening ? Icons.stop : Icons.mic, color: Colors.white),
              ),
            ),
          Expanded(
            child: TextField(
              controller: _c,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(hintText: _listening ? 'Listening… speak now' : 'Ask or tell me anything…'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _thinking ? null : () => _send(), icon: const Icon(Icons.send)),
        ]),
      ),
    ]);
  }
}
