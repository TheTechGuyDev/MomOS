import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/profile_service.dart';
import '../core/theme.dart';

class FamilySetupScreen extends StatefulWidget {
  final VoidCallback onDone;
  const FamilySetupScreen({super.key, required this.onDone});
  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  final _name = TextEditingController(text: 'Hassan Family');
  final _code = TextEditingController();
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      widget.onDone();
    } on PostgrestException catch (e) {
      _toast(e.message.contains('Invalid') ? 'That family code was not found.' : e.message);
    } catch (_) {
      _toast('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your family'),
        actions: [
          TextButton(onPressed: () => supa.auth.signOut(), child: const Text('Sign out')),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Card(
                  emoji: '🏡',
                  title: 'Start a new family',
                  subtitle: 'For the first person setting up MomOS.',
                  child: Column(children: [
                    TextField(controller: _name, decoration: const InputDecoration(hintText: 'Family name')),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy ? null : () => _run(() => ProfileService.createFamily(_name.text)),
                      child: const Text('Create family'),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Text('or', textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 16),
                _Card(
                  emoji: '🔑',
                  title: 'Join with a family code',
                  subtitle: 'Find the code on the Home screen of the first account.',
                  child: Column(children: [
                    TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(hintText: 'e.g. 4F9A2C'),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                      onPressed: _busy ? null : () => _run(() => ProfileService.joinFamily(_code.text)),
                      child: const Text('Join family'),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String emoji, title, subtitle;
  final Widget child;
  const _Card({required this.emoji, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          Text(subtitle, style: t.bodySmall?.copyWith(color: AppColors.muted)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
