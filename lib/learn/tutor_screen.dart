import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import 'learn_service.dart';

class TutorScreen extends StatefulWidget {
  final String? lessonTitle;
  const TutorScreen({super.key, this.lessonTitle});
  @override
  State<TutorScreen> createState() => _TutorScreenState();
}

class _TutorScreenState extends State<TutorScreen> {
  final _c = TextEditingController();
  final _scroll = ScrollController();
  final List<TutorMessage> _msgs = [];
  bool _thinking = false;

  List<String> get _starters => widget.lessonTitle != null
      ? ['Explain "${widget.lessonTitle}" more simply', 'Give me a practice exercise', 'Show me a real-life example']
      : ['What does a data analyst do?', 'Explain VLOOKUP simply', 'Help me write a SQL query', 'How do I get my first analyst job?'];

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _c.text).trim();
    if (text.isEmpty || _thinking) return;
    _c.clear();
    setState(() {
      _msgs.add(TutorMessage('user', text));
      _thinking = true;
    });
    _toBottom();
    try {
      final history = _msgs.length > 12 ? _msgs.sublist(_msgs.length - 12) : List<TutorMessage>.from(_msgs);
      final reply = await LearnService.askTutor(history, lessonTitle: widget.lessonTitle);
      setState(() => _msgs.add(TutorMessage('assistant', reply)));
    } catch (e) {
      setState(() => _msgs.add(TutorMessage('assistant', '⚠️ ${e.toString().replaceFirst('Exception: ', '')}')));
    } finally {
      setState(() => _thinking = false);
      _toBottom();
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('AI tutor ✨')),
      body: Column(children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              if (_msgs.isEmpty) ...[
                const SizedBox(height: 20),
                const Center(child: Text('🎓', style: TextStyle(fontSize: 56))),
                const SizedBox(height: 8),
                Text('Ask me anything about data analysis', textAlign: TextAlign.center,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                Text('Excel, SQL, Power BI, Python or careers. I explain things simply.',
                    textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 18),
                ..._starters.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.all(14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _send(s),
                        child: Text(s),
                      ),
                    )),
              ],
              ..._msgs.map((m) {
                final me = m.role == 'user';
                return Align(
                  alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                    margin: const EdgeInsets.only(bottom: 10),
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
                );
              }),
              if (_thinking)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(padding: EdgeInsets.all(8), child: Text('Thinking…', style: TextStyle(color: AppColors.muted))),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _c,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Ask a question…'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _thinking ? null : () => _send(), icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
