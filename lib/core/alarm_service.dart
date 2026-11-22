import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app_events.dart';
import 'memory_service.dart';
import 'push.dart';
import 'theme.dart';
import 'time_utils.dart';

/// While the app is open, watches for reminders that become due and
/// plays a chime (gentle), shows a banner (important) or opens the
/// full-screen alarm that keeps ringing until Stop (alarm).
class AlarmWatcher extends StatefulWidget {
  final Widget child;
  const AlarmWatcher({super.key, required this.child});
  @override
  State<AlarmWatcher> createState() => _AlarmWatcherState();
}

class _AlarmWatcherState extends State<AlarmWatcher> {
  final _seen = <String>{};
  Timer? _poll;
  Timer? _inbox;
  bool _alarmOpen = false;
  final _chime = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _check();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _check());
    _inbox = Timer.periodic(const Duration(seconds: 2), (_) => _readInbox());
    // Opened from an alarm notification (#alarm=<id>)
    final frag = Uri.base.fragment;
    if (frag.startsWith('alarm=')) {
      final id = frag.substring(6);
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAlarmById(id));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _inbox?.cancel();
    _chime.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final due = await MemoryService.dueNow();
      for (final r in due) {
        await _handle(r);
      }
    } catch (_) {}
  }

  void _readInbox() {
    for (final m in PushService.takeInbox()) {
      final p = Map<String, dynamic>.from((m['payload'] ?? {}) as Map);
      if (p['kind'] == 'reminder' && p['rid'] != null) {
        if (m['type'] == 'momos-open' && p['level'] == 'alarm') {
          _openAlarmById(p['rid'] as String);
        } else {
          _check();
        }
      }
    }
  }

  Future<void> _openAlarmById(String id) async {
    try {
      final due = await MemoryService.dueNow();
      final r = due.where((x) => x['id'] == id).firstOrNull;
      if (r != null) {
        _seen.remove(id);
        await _handle({...r, 'level': 'alarm'});
      }
    } catch (_) {}
  }

  Future<void> _handle(Map<String, dynamic> r) async {
    final id = r['id'] as String;
    if (_seen.contains(id) || !mounted) return;
    _seen.add(id);
    final level = (r['level'] ?? 'gentle') as String;
    final title = r['title'] as String;
    if (level == 'alarm') {
      if (_alarmOpen) return;
      _alarmOpen = true;
      await Navigator.of(context).push(PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, _, _) => AlarmScreen(reminder: r),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ));
      _alarmOpen = false;
      AppEvents.bump();
      return;
    }
    try {
      await _chime.play(AssetSource('sounds/chime.wav'), volume: 0.9);
    } catch (_) {}
    PushService.vibrate(level == 'important' ? [300, 150, 300] : [150]);
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(MaterialBanner(
      backgroundColor: level == 'important' ? const Color(0xFFFFF1E6) : Colors.white,
      leading: Text(level == 'important' ? '⚠️' : '🔔', style: const TextStyle(fontSize: 26)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        if (r['notes'] != null) Text('${r['notes']}', style: const TextStyle(fontSize: 12)),
      ]),
      actions: [
        TextButton(
          onPressed: () async {
            messenger.hideCurrentMaterialBanner();
            await MemoryService.snooze(id, Duration(minutes: level == 'important' ? 10 : 60));
            _seen.remove(id);
          },
          child: Text(level == 'important' ? '10 min' : '1 hour'),
        ),
        FilledButton(
          onPressed: () async {
            messenger.hideCurrentMaterialBanner();
            await MemoryService.setReminderDone(id, true);
          },
          child: const Text('Done'),
        ),
      ],
    ));
    if (level == 'gentle') {
      Future.delayed(const Duration(seconds: 25), () {
        if (mounted) messenger.hideCurrentMaterialBanner();
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Full-screen alarm. The sound loops until Stop, Done or Snooze is tapped.
class AlarmScreen extends StatefulWidget {
  final Map<String, dynamic> reminder;
  const AlarmScreen({super.key, required this.reminder});
  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  Timer? _vibe;
  bool _soundBlocked = false;
  Map<String, dynamic>? _next;

  String get _id => widget.reminder['id'] as String;

  @override
  void initState() {
    super.initState();
    _start();
    _vibe = Timer.periodic(const Duration(seconds: 3), (_) => PushService.vibrate([700, 250, 700]));
    final due = DateTime.tryParse('${widget.reminder['due_at']}') ?? DateTime.now();
    MemoryService.nextUp(due).then((n) {
      if (mounted) setState(() => _next = n);
    }).catchError((_) {});
  }

  Future<void> _start() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('sounds/alarm.wav'), volume: 1.0);
      if (mounted) setState(() => _soundBlocked = false);
    } catch (_) {
      if (mounted) setState(() => _soundBlocked = true);
    }
  }

  Future<void> _finish(Future<void> Function() action) async {
    _vibe?.cancel();
    await _player.stop();
    try {
      await action();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _vibe?.cancel();
    _player.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = widget.reminder;
    final due = DateTime.tryParse('${r['due_at']}')?.toLocal();
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF7C6BD6), AppColors.primary],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Spacer(),
                ScaleTransition(
                  scale: Tween(begin: 0.9, end: 1.1).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                  child: Container(
                    width: 150,
                    height: 150,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.2),
                      boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 40)],
                    ),
                    child: const Text('⏰', style: TextStyle(fontSize: 72)),
                  ),
                ),
                const SizedBox(height: 28),
                if (due != null)
                  Text(clock(due), style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('${r['title']}',
                    textAlign: TextAlign.center,
                    style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                if (r['notes'] != null) ...[
                  const SizedBox(height: 6),
                  Text('${r['notes']}', textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: Colors.white70)),
                ],
                if (_next != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      'Next up: ${_next!['title']} at ${clock(DateTime.parse('${_next!['due_at']}').toLocal())}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
                if (_soundBlocked) ...[
                  const SizedBox(height: 14),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: _start,
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Tap to play the alarm sound'),
                  ),
                ],
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(64),
                      textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                    onPressed: () => _finish(() => MemoryService.stopAlarm(_id)),
                    child: const Text('🛑  Stop'),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: () => _finish(() => MemoryService.snooze(_id, const Duration(minutes: 10))),
                      child: const Text('Snooze 10 min'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        minimumSize: const Size.fromHeight(54),
                      ),
                      onPressed: () => _finish(() => MemoryService.setReminderDone(_id, true)),
                      child: const Text('✅ Done'),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
