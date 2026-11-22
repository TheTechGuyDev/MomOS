import 'package:material_ui/material_ui.dart';

import '../core/profile_service.dart';
import '../core/push.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/ui.dart';

const _avatars = ['🌸', '🌷', '🦋', '👩🏾', '👩🏿', '👨🏾', '👨🏿', '👑', '⭐', '🌻', '🌙', '💜'];

class SettingsScreen extends StatefulWidget {
  final Profile profile;
  const SettingsScreen({super.key, required this.profile});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _name = TextEditingController(text: widget.profile.displayName);
  late String _avatar = widget.profile.avatar;
  late String _role = widget.profile.role;
  String _push = PushService.status();
  late int _quietStart = widget.profile.quietStart;
  late int _quietEnd = widget.profile.quietEnd;
  late bool _summary = widget.profile.morningSummary;
  late int _summaryHour = widget.profile.summaryHour;

  String _h(int h) => '${h % 12 == 0 ? 12 : h % 12} ${h < 12 ? 'AM' : 'PM'}';

  Future<void> _saveNotifyPrefs() async {
    try {
      await supa.from('profiles').update({
        'quiet_start': _quietStart,
        'quiet_end': _quietEnd,
        'morning_summary': _summary,
        'summary_hour': _summaryHour,
      }).eq('id', AppSession.uid);
      _changed = true;
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Please try again.');
    }
  }

  Future<void> _pickHour(int current, ValueChanged<int> onPick, {int min = 0, int max = 23}) async {
    final h = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 320,
          child: ListView(children: [
            for (var i = min; i <= max; i++)
              ListTile(
                title: Text(_h(i), style: TextStyle(fontWeight: i == current ? FontWeight.w900 : FontWeight.w500)),
                trailing: i == current ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(ctx, i),
              ),
          ]),
        ),
      ),
    );
    if (h != null) {
      onPick(h);
      _saveNotifyPrefs();
    }
  }
  bool _saving = false;
  bool _pushBusy = false;
  bool _changed = false;

  Future<void> _saveProfile() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await supa.from('profiles').update({
        'display_name': _name.text.trim(),
        'avatar_emoji': _avatar,
        'role': _role,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', AppSession.uid);
      _changed = true;
      if (mounted) toast(context, 'Profile saved');
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _enablePush() async {
    setState(() => _pushBusy = true);
    try {
      final err = await PushService.enable();
      if (!mounted) return;
      if (err != null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Notifications'),
            content: Text(err),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      } else {
        toast(context, 'Notifications are on 🔔');
      }
    } catch (_) {
      if (mounted) toast(context, 'Could not turn on notifications.');
    } finally {
      if (mounted) {
        setState(() {
          _pushBusy = false;
          _push = PushService.status();
        });
      }
    }
  }

  Future<void> _test([String level = 'gentle']) async {
    setState(() => _pushBusy = true);
    try {
      final n = await PushService.sendTest(level: level);
      if (mounted) toast(context, n > 0 ? 'Test sent. Check your notifications.' : 'No device is set up yet. Tap "Turn on" first.');
    } catch (_) {
      if (mounted) toast(context, 'Could not send a test.');
    } finally {
      if (mounted) setState(() => _pushBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pushOn = _push == 'granted';
    String pushText;
    switch (_push) {
      case 'granted':
        pushText = 'On for this device. You\'ll get reminders and family events.';
        break;
      case 'denied':
        pushText = 'Blocked in your browser settings. Allow notifications for this site to turn them on.';
        break;
      case 'needs-install':
        pushText = 'On iPhone: tap Share → Add to Home Screen, open MomOS from the Home Screen, then turn this on.';
        break;
      case 'unsupported':
        pushText = 'This browser can\'t show notifications.';
        break;
      default:
        pushText = 'Get a ping when a reminder is due or a family event is coming up.';
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: BackButton(onPressed: () => Navigator.of(context).pop(_changed)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            WhiteCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Profile', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _avatars
                      .map((a) => GestureDetector(
                            onTap: () => setState(() => _avatar = a),
                            child: Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _avatar == a ? AppColors.primary.withValues(alpha: 0.18) : AppColors.bg,
                                shape: BoxShape.circle,
                                border: Border.all(color: _avatar == a ? AppColors.primary : Colors.transparent, width: 2),
                              ),
                              child: Text(a, style: const TextStyle(fontSize: 22)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
                TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'Your name')),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'mom', label: Text('Mum')),
                    ButtonSegment(value: 'dad', label: Text('Dad')),
                    ButtonSegment(value: 'other', label: Text('Other')),
                  ],
                  selected: {_role},
                  onSelectionChanged: (s) => setState(() => _role = s.first),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _saving ? null : _saveProfile, child: const Text('Save profile')),
              ]),
            ),
            const SizedBox(height: 14),
            WhiteCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Text(pushOn ? '🔔' : '🔕', style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Notifications', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                  if (pushOn)
                    const Chip(label: Text('On', style: TextStyle(fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 6),
                Text(pushText, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 12),
                if (_push == 'default' || _push == 'granted')
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _pushBusy ? null : _enablePush,
                        child: Text(pushOn ? 'Re-connect this device' : 'Turn on'),
                      ),
                    ),
                  ]),
                if (pushOn) ...[
                  const SizedBox(height: 12),
                  const Text('Try each type:', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    ActionChip(label: const Text('🔔 Gentle'), onPressed: _pushBusy ? null : () => _test('gentle')),
                    ActionChip(label: const Text('⚠️ Important'), onPressed: _pushBusy ? null : () => _test('important')),
                    ActionChip(label: const Text('⏰ Alarm'), onPressed: _pushBusy ? null : () => _test('alarm')),
                  ]),
                ],
                const Divider(height: 28),
                Row(children: [
                  const Text('🌙', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Quiet hours', style: TextStyle(fontWeight: FontWeight.w900)),
                      Text('Only ⏰ Alarms come through', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ]),
                  ),
                  TextButton(
                    onPressed: () => _pickHour(_quietStart, (h) => setState(() => _quietStart = h)),
                    child: Text(_h(_quietStart)),
                  ),
                  const Text('to'),
                  TextButton(
                    onPressed: () => _pickHour(_quietEnd, (h) => setState(() => _quietEnd = h)),
                    child: Text(_h(_quietEnd)),
                  ),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _summary,
                  onChanged: (v) {
                    setState(() => _summary = v);
                    _saveNotifyPrefs();
                  },
                  secondary: const Text('☀️', style: TextStyle(fontSize: 22)),
                  title: const Text('Morning summary', style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('One message at ${_h(_summaryHour)} with your plan for the day'),
                ),
                if (_summary)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _pickHour(_summaryHour, (h) => setState(() => _summaryHour = h), min: 4, max: 11),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text('Change time (${_h(_summaryHour)})'),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            WhiteCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('📲 Install MomOS', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Android (Chrome): ⋮ menu → Add to Home screen / Install app.'),
                const SizedBox(height: 4),
                const Text('iPhone (Safari): Share button → Add to Home Screen.'),
                const SizedBox(height: 4),
                Text('It then opens full screen like a normal app and loads faster.',
                    style: t.bodySmall?.copyWith(color: AppColors.muted)),
              ]),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: Colors.red.shade400,
                side: BorderSide(color: Colors.red.shade200),
              ),
              onPressed: () async {
                AppSession.clear();
                await supa.auth.signOut();
                if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
