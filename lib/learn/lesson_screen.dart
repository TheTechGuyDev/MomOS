import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/game_service.dart';
import '../core/theme.dart';
import '../widgets/celebration.dart';
import '../widgets/ui.dart';
import 'certificate_screen.dart';
import 'content.dart';
import 'learn_service.dart';
import 'sheet_lab.dart';
import 'sql_lab.dart';
import 'tutor_screen.dart';

/// Renders the lesson mini-markup.
class LessonBody extends StatelessWidget {
  final String text;
  const LessonBody(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final widgets = <Widget>[];
    final lines = text.trim().split('\n');
    var inCode = false;
    final code = StringBuffer();

    InlineSpan rich(String s, TextStyle? base) {
      final parts = s.split('**');
      return TextSpan(
        style: base,
        children: [
          for (var i = 0; i < parts.length; i++)
            TextSpan(text: parts[i], style: i.isOdd ? const TextStyle(fontWeight: FontWeight.w900) : null),
        ],
      );
    }

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.startsWith('```')) {
        if (inCode) {
          final c = code.toString().trimRight();
          widgets.add(Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF2D2640), borderRadius: BorderRadius.circular(14)),
            child: Stack(children: [
              SelectableText(c, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFF8E6EE), fontSize: 13, height: 1.5)),
              Positioned(
                right: -8,
                top: -8,
                child: IconButton(
                  tooltip: 'Copy',
                  icon: const Icon(Icons.copy, size: 16, color: Colors.white54),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: c));
                    toast(context, 'Copied');
                  },
                ),
              ),
            ]),
          ));
          code.clear();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        code.writeln(raw);
        continue;
      }
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(line.substring(3), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: AppColors.secondary)),
        ));
      } else if (line.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('•  ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 16)),
            Expanded(child: Text.rich(rich(line.substring(2), t.bodyLarge))),
          ]),
        ));
      } else if (line.startsWith('> ')) {
        widgets.add(Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.sun.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💡 '),
            Expanded(child: Text.rich(rich(line.substring(2), t.bodyMedium))),
          ]),
        ));
      } else {
        widgets.add(Text.rich(rich(line, t.bodyLarge?.copyWith(height: 1.45))));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets);
  }
}

class LessonScreen extends StatefulWidget {
  final Lesson lesson;
  final bool alreadyDone;
  const LessonScreen({super.key, required this.lesson, this.alreadyDone = false});
  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  bool _quiz = false;
  int _qi = 0;
  int? _picked;
  int _score = 0;
  bool _submitting = false;
  bool _finished = false;
  String? _resultMsg;

  Lesson get l => widget.lesson;

  Future<void> _openVideo() async {
    final url = Uri.parse('https://www.youtube.com/results?search_query=${Uri.encodeComponent(l.video)}');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  void _answer(int i) {
    if (_picked != null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _picked = i;
      if (i == l.quiz[_qi].answer) _score++;
    });
  }

  Future<void> _next() async {
    if (_qi < l.quiz.length - 1) {
      setState(() {
        _qi++;
        _picked = null;
      });
      return;
    }
    setState(() => _submitting = true);
    try {
      final r = await LearnService.completeLesson(l.key, _score, l.quiz.length);
      if (!mounted) return;
      setState(() {
        _finished = true;
        _resultMsg = r.firstTime
            ? (r.gained > 0 ? 'Lesson complete! +${r.gained} XP' : 'Lesson complete!')
            : 'Nice revision! Your best score is saved.';
      });
      final all = await GameService.allBadges();
      final newOnes = all.where((b) => r.newBadges.contains(b.key)).toList();
      if (newOnes.isNotEmpty && mounted) await showCelebration(context, badges: newOnes);
      if (r.trackCompleted != null && mounted) {
        final track = tracks.firstWhere((t) => t.key == r.trackCompleted);
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CertificateScreen(track: track, earnedOn: DateTime.now())));
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _finished = true;
        _resultMsg = e.message;
      });
    } catch (_) {
      if (mounted) toast(context, 'Could not save your result. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _retry() => setState(() {
        _qi = 0;
        _picked = null;
        _score = 0;
        _finished = false;
        _resultMsg = null;
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.title),
        actions: [
          IconButton(
            tooltip: 'Ask the AI tutor',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TutorScreen(lessonTitle: l.title))),
          ),
        ],
      ),
      body: _quiz ? _quizView(t) : _lessonView(t),
    );
  }

  Widget _lessonView(TextTheme t) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Row(children: [
          Chip(avatar: const Icon(Icons.timer_outlined, size: 16), label: Text('${l.minutes} min')),
          const SizedBox(width: 8),
          if (widget.alreadyDone) const Chip(avatar: Icon(Icons.check_circle, size: 16, color: AppColors.mint), label: Text('Completed')),
        ]),
        const SizedBox(height: 8),
        LessonBody(l.body),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _openVideo,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Watch videos'),
            ),
          ),
          if (l.practice != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => l.practice == 'sql' ? const SqlLabScreen() : const SheetLabScreen(),
                )),
                icon: Icon(l.practice == 'sql' ? Icons.storage : Icons.grid_on),
                label: Text(l.practice == 'sql' ? 'SQL Lab' : 'Sheet Lab'),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => setState(() => _quiz = true),
          icon: const Icon(Icons.quiz_outlined),
          label: Text(widget.alreadyDone ? 'Retake the quiz' : 'Take the quiz · +20 XP'),
        ),
      ],
    );
  }

  Widget _quizView(TextTheme t) {
    if (_finished) {
      final passed = _score * 3 >= l.quiz.length * 2;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(passed ? '🎉' : '💪', style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 10),
            Text('$_score / ${l.quiz.length} correct', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(_resultMsg ?? '', textAlign: TextAlign.center, style: t.bodyLarge?.copyWith(color: AppColors.muted)),
            const SizedBox(height: 22),
            if (!passed) FilledButton(onPressed: _retry, child: const Text('Try again')),
            if (passed) FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Back to lessons')),
            TextButton(onPressed: () => setState(() => _quiz = false), child: const Text('Read the lesson again')),
          ]),
        ),
      );
    }
    final q = l.quiz[_qi];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: (_qi + 1) / l.quiz.length, minHeight: 8),
        ),
        const SizedBox(height: 8),
        Text('Question ${_qi + 1} of ${l.quiz.length}', style: t.bodySmall?.copyWith(color: AppColors.muted)),
        const SizedBox(height: 10),
        Text(q.q, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        ...List.generate(q.options.length, (i) {
          Color border = const Color(0xFFF0E6E9);
          Color fill = Colors.white;
          if (_picked != null) {
            if (i == q.answer) {
              border = AppColors.mint;
              fill = AppColors.mint.withValues(alpha: 0.12);
            } else if (i == _picked) {
              border = Colors.red.shade300;
              fill = Colors.red.shade50;
            }
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: fill,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: border, width: 1.5)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _answer(i),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Expanded(child: Text(q.options[i], style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (_picked != null && i == q.answer) const Icon(Icons.check_circle, color: AppColors.mint),
                    if (_picked == i && i != q.answer) Icon(Icons.cancel, color: Colors.red.shade300),
                  ]),
                ),
              ),
            ),
          );
        }),
        if (_picked != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
            child: Text(q.why),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _next,
            child: Text(_qi < l.quiz.length - 1 ? 'Next question' : 'See my result'),
          ),
        ],
      ],
    );
  }
}
