import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/kids_service.dart';
import '../core/profile_service.dart';
import '../core/theme.dart';
import '../core/time_utils.dart';
import '../widgets/ui.dart';
import 'triage.dart';

const _urgencyStyle = {
  'emergency': ('🚨', 'Get help now', 'Go to the nearest hospital emergency unit now, or call 112.', Color(0xFFD64545)),
  'doctor_today': ('🩺', 'See a doctor today', 'Visit a clinic or hospital today. Don\'t wait for it to get worse.', Color(0xFFE8892B)),
  'doctor_soon': ('📅', 'Book a clinic visit', 'See a doctor or nurse in the next 1–2 days, sooner if it gets worse.', Color(0xFFC9A227)),
  'self_care': ('🌿', 'Care at home for now', 'This can usually be managed at home. Watch for the warning signs below.', Color(0xFF3FA587)),
};

class SymptomCheckerScreen extends StatefulWidget {
  const SymptomCheckerScreen({super.key});
  @override
  State<SymptomCheckerScreen> createState() => _SymptomCheckerScreenState();
}

class _SymptomCheckerScreenState extends State<SymptomCheckerScreen> {
  int _step = 0;
  Who? _who;
  Child? _child;
  List<Child> _children = [];
  final _symptoms = <String>{};
  final _notes = TextEditingController();
  int _duration = 0, _temp = 0, _severity = 0;
  final _flags = <String>{};
  Triage? _triage;
  Map<String, dynamic>? _ai;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    KidsService.children().then((c) {
      if (mounted) setState(() => _children = c);
    }).catchError((_) {});
  }

  int get _ageMonths {
    if (_who == Who.mum) {
      final youngest = _children.isEmpty ? null : _children.reduce((a, b) => a.birthDate.isAfter(b.birthDate) ? a : b);
      return youngest?.ageMonths ?? 12;
    }
    return _child?.ageMonths ?? 36;
  }

  String get _personText {
    switch (_who) {
      case Who.mum:
        return 'Mother, ${_ageMonths <= 12 ? 'about $_ageMonths months after giving birth, may be breastfeeding' : 'adult woman'}';
      case Who.baby:
        return 'Baby ${_child?.name ?? ''}, ${_child == null ? 'under 3' : ageText(_child!.birthDate)}';
      case Who.child:
        return 'Child ${_child?.name ?? ''}, ${_child == null ? 'over 3' : ageText(_child!.birthDate)}';
      default:
        return '';
    }
  }

  Future<void> _finish() async {
    final t = decide(
      who: _who!,
      ageMonths: _ageMonths,
      flags: _flags,
      tempBand: _temp,
      duration: _duration,
      severity: _severity,
      symptoms: _symptoms,
    );
    setState(() {
      _triage = t;
      _step = 4;
      _aiLoading = true;
    });
    final answers = {
      'duration': ['less than a day', '1-3 days', '4-7 days', 'more than a week'][_duration],
      'temperature': ['none or not measured', '37.5-37.9C', '38-38.9C', '39C or higher'][_temp],
      'severity': ['mild', 'moderate', 'severe'][_severity],
      'warning_signs': _flags.toList(),
    };
    Map<String, dynamic>? ai;
    try {
      final r = await supa.functions.invoke('symptom-check', body: {
        'person': _personText,
        'symptoms': _symptoms.toList(),
        'answers': answers,
        'urgency': t.urgency,
        'notes': _notes.text,
      });
      final d = r.data is String ? jsonDecode(r.data as String) : r.data;
      if (d is Map && d['possible_causes'] != null) ai = Map<String, dynamic>.from(d);
    } catch (_) {}
    ai ??= _fallback();
    if (!mounted) return;
    setState(() {
      _ai = ai;
      _aiLoading = false;
    });
    try {
      await supa.from('health_checks').insert({
        'who': _personText,
        'symptoms': _symptoms.toList(),
        'answers': answers,
        'urgency': t.urgency,
        'result': {'reasons': t.reasons, ...ai},
      });
    } catch (_) {}
  }

  Map<String, dynamic> _fallback() {
    final causes = <Map<String, String>>[];
    final care = <String>[];
    for (final s in _symptoms) {
      final f = fallbackTips[s];
      if (f == null) continue;
      for (final c in f.$1) {
        causes.add({'name': c, 'why': 'Common with $s'.toLowerCase().replaceFirst('common', 'Common')});
      }
      care.addAll(f.$2);
    }
    return {
      'possible_causes': causes.take(4).toList(),
      'self_care': care.toSet().take(5).toList(),
      'watch_for': redFlagsFor[_who]!.take(4).map((f) => f.question).toList(),
      'ask_doctor': ['What could be causing this?', 'Is a test needed (for example malaria)?'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Symptom checker'),
        actions: [
          IconButton(
            tooltip: 'Past checks',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const _HistoryScreen())),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(_step), child: _body()),
      ),
    );
  }

  Widget _body() {
    switch (_step) {
      case 0:
        return _whoStep();
      case 1:
        return _symptomStep();
      case 2:
        return _surveyStep();
      case 3:
        return _flagStep();
      default:
        return _resultStep();
    }
  }

  Widget _progress(int n) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Step $n of 4', style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: n / 4, minHeight: 6)),
        ]),
      );

  Widget _whoStep() {
    final t = Theme.of(context).textTheme;
    final babies = _children.where((c) => c.isBaby).toList();
    final kids = _children.where((c) => !c.isBaby).toList();
    Widget option(String emoji, String title, String sub, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: WhiteCard(
            onTap: onTap,
            child: Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
              ),
              const Icon(Icons.chevron_right),
            ]),
          ),
        );
    void pick(Who w, [Child? c]) => setState(() {
          _who = w;
          _child = c;
          _symptoms.clear();
          _flags.clear();
          _step = 1;
        });
    return ListView(padding: const EdgeInsets.all(20), children: [
      _progress(1),
      Text('Who is not feeling well?', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      option('🌸', 'Me', 'Mum', () => pick(Who.mum)),
      ...babies.map((c) => option(c.emoji, c.name, 'Baby · ${ageText(c.birthDate)}', () => pick(Who.baby, c))),
      ...kids.map((c) => option(c.emoji, c.name, ageText(c.birthDate), () => pick(Who.child, c))),
      if (_children.isEmpty) ...[
        option('👶', 'A baby (under 3)', 'Add your children in the Kids tab for better results', () => pick(Who.baby)),
        option('🧒', 'A child (3 or older)', '', () => pick(Who.child)),
      ],
      const SizedBox(height: 10),
      const _Disclaimer(),
    ]);
  }

  Widget _symptomStep() {
    final t = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(20), children: [
      _progress(2),
      Text('What symptoms do you notice?', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      Text('Tap all that apply', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: symptomsFor[_who]!
            .map((s) => FilterChip(
                  label: Text(s),
                  selected: _symptoms.contains(s),
                  onSelected: (v) => setState(() => v ? _symptoms.add(s) : _symptoms.remove(s)),
                ))
            .toList(),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _notes,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Anything else? (optional)'),
      ),
      const SizedBox(height: 18),
      Row(children: [
        TextButton(onPressed: () => setState(() => _step = 0), child: const Text('Back')),
        const Spacer(),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
          onPressed: _symptoms.isEmpty && _notes.text.trim().isEmpty ? null : () => setState(() => _step = 2),
          child: const Text('Next'),
        ),
      ]),
    ]);
  }

  Widget _surveyStep() {
    final t = Theme.of(context).textTheme;
    Widget q(String title, List<String> opts, int value, ValueChanged<int> on) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < opts.length; i++)
                  ChoiceChip(label: Text(opts[i]), selected: value == i, onSelected: (_) => setState(() => on(i))),
              ],
            ),
          ]),
        );
    return ListView(padding: const EdgeInsets.all(20), children: [
      _progress(3),
      Text('A few quick questions', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      q('How long has this been going on?', ['Less than a day', '1–3 days', '4–7 days', 'Over a week'], _duration, (v) => _duration = v),
      q('Highest temperature?', ['No fever / not checked', '37.5–37.9°C', '38–38.9°C', '39°C or more'], _temp, (v) => _temp = v),
      q('How bad is it?', ['Mild', 'Moderate', 'Severe'], _severity, (v) => _severity = v),
      Row(children: [
        TextButton(onPressed: () => setState(() => _step = 1), child: const Text('Back')),
        const Spacer(),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(140, 52)),
          onPressed: () => setState(() => _step = 3),
          child: const Text('Next'),
        ),
      ]),
    ]);
  }

  Widget _flagStep() {
    final t = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(20), children: [
      _progress(4),
      Text('Any of these warning signs?', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
      Text('Tick any that are happening now', style: t.bodyMedium?.copyWith(color: AppColors.muted)),
      const SizedBox(height: 12),
      ...redFlagsFor[_who]!.map((f) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: _flags.contains(f.key) ? const Color(0xFFFDECEC) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: CheckboxListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                value: _flags.contains(f.key),
                onChanged: (v) => setState(() => v == true ? _flags.add(f.key) : _flags.remove(f.key)),
                title: Text(f.question, style: const TextStyle(fontWeight: FontWeight.w700)),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
          )),
      const SizedBox(height: 14),
      Row(children: [
        TextButton(onPressed: () => setState(() => _step = 2), child: const Text('Back')),
        const Spacer(),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(160, 52)),
          onPressed: _finish,
          child: Text(_flags.isEmpty ? 'None of these' : 'See advice'),
        ),
      ]),
    ]);
  }

  Widget _resultStep() {
    final t = Theme.of(context).textTheme;
    final tr = _triage!;
    final st = _urgencyStyle[tr.urgency]!;
    final selfHarm = _flags.contains('self_harm');
    List<dynamic> list(String k) => (_ai?[k] as List?) ?? [];
    return ListView(padding: const EdgeInsets.all(20), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: st.$4, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(st.$1, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 10),
            Expanded(child: Text(st.$2, style: t.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 8),
          Text(st.$3, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          if (tr.urgency == 'emergency') ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: st.$4),
              onPressed: () => launchUrl(Uri.parse('tel:112')),
              icon: const Icon(Icons.call),
              label: const Text('Call 112'),
            ),
          ],
        ]),
      ),
      if (selfHarm) ...[
        const SizedBox(height: 12),
        WhiteCard(
          color: const Color(0xFFFFF0F3),
          child: const Text(
            '💗 You are not alone, and these feelings can happen after having a baby. Please tell someone you trust right now '
            'and get help today: go to the nearest hospital or call 112. Your doctor can help, and it gets better with support.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
      if (tr.reasons.isNotEmpty) ...[
        const SectionTitle('Why'),
        ...tr.reasons.map((r) => _bullet('•', r)),
      ],
      if (_aiLoading)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Column(children: [CircularProgressIndicator(), SizedBox(height: 8), Text('Preparing tips…')]),
        )
      else ...[
        if (list('possible_causes').isNotEmpty) ...[
          const SectionTitle('Possible causes'),
          ...list('possible_causes').map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WhiteCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    if ((c['why'] ?? '').toString().isNotEmpty)
                      Text('${c['why']}', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ]),
                ),
              )),
        ],
        if (list('self_care').isNotEmpty) ...[
          const SectionTitle('What you can do now'),
          ...list('self_care').map((s) => _bullet('✅', '$s')),
        ],
        if (list('watch_for').isNotEmpty) ...[
          const SectionTitle('Get help quickly if'),
          ...list('watch_for').map((s) => _bullet('⚠️', '$s')),
        ],
        if (list('ask_doctor').isNotEmpty) ...[
          const SectionTitle('Questions to ask the doctor'),
          ...list('ask_doctor').map((s) => _bullet('❓', '$s')),
        ],
      ],
      const SizedBox(height: 14),
      const _Disclaimer(),
      const SizedBox(height: 14),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        onPressed: () => setState(() {
          _step = 0;
          _triage = null;
          _ai = null;
          _symptoms.clear();
          _flags.clear();
          _notes.clear();
          _duration = _temp = _severity = 0;
        }),
        child: const Text('Start a new check'),
      ),
    ]);
  }

  Widget _bullet(String icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$icon  '),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.35))),
        ]),
      );
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: const Text(
        'This gives general guidance, not a diagnosis. If you are worried, or things get worse, see a doctor. '
        'For medicines, follow the label or ask a pharmacist, especially for babies and children.',
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    );
  }
}

class _HistoryScreen extends StatelessWidget {
  const _HistoryScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Past checks')),
      body: FutureBuilder(
        future: supa.from('health_checks').select().order('created_at', ascending: false).limit(50),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data as List;
          if (rows.isEmpty) {
            return const EmptyState(emoji: '🩺', title: 'No checks yet', subtitle: 'Your symptom checks are saved here, privately.');
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: rows.map((r) {
              final st = _urgencyStyle[r['urgency']] ?? _urgencyStyle['doctor_soon']!;
              final at = DateTime.parse(r['created_at'] as String).toLocal();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WhiteCard(
                  child: Row(children: [
                    Text(st.$1, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r['who']}', style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text((r['symptoms'] as List).join(', '), style: const TextStyle(fontSize: 13)),
                        Text('${shortDate(at)} · ${st.$2}', style: TextStyle(fontSize: 12, color: st.$4, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ]),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
