import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme.dart';
import '../widgets/ui.dart';
import 'learn_service.dart';

const _toolOptions = ['Excel', 'Google Sheets', 'SQL', 'Power BI', 'Looker Studio', 'Python', 'pandas', 'Tableau'];

Future<bool?> _showProjectSheet(BuildContext context, {PortfolioProject? existing}) {
  final title = TextEditingController(text: existing?.title ?? '');
  final desc = TextEditingController(text: existing?.description ?? '');
  final link = TextEditingController(text: existing?.link ?? '');
  final tools = {...?existing?.tools};
  var saving = false;
  return showAppSheet<bool>(context, existing == null ? 'Add a project' : 'Edit project', (ctx, setS) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        controller: title,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Project title (e.g. Lagos shop sales dashboard)'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: desc,
        minLines: 3,
        maxLines: 6,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'The question, what you did, and what you found'),
      ),
      const SizedBox(height: 12),
      const Text('Tools used', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _toolOptions
            .map((tl) => FilterChip(
                  label: Text(tl),
                  selected: tools.contains(tl),
                  onSelected: (v) => setS(() => v ? tools.add(tl) : tools.remove(tl)),
                ))
            .toList(),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: link,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(hintText: 'Link (GitHub, Google Drive, LinkedIn post…)', prefixIcon: Icon(Icons.link)),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                if (title.text.trim().isEmpty) return;
                setS(() => saving = true);
                try {
                  await LearnService.saveProject(
                      id: existing?.id, title: title.text, description: desc.text, tools: tools.toList(), link: link.text);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (_) {
                  setS(() => saving = false);
                  if (ctx.mounted) toast(ctx, 'Could not save. Please try again.');
                }
              },
        child: const Text('Save project'),
      ),
    ]);
  });
}

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});
  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  List<PortfolioProject> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await LearnService.portfolio();
      if (mounted) {
        setState(() {
          _items = p;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('My portfolio')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await _showProjectSheet(context) == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add project'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              children: [
                if (_items.isEmpty)
                  const EmptyState(
                    emoji: '💼',
                    title: 'Show employers what you can do',
                    subtitle: 'Aim for 3 projects: an Excel dashboard, a SQL analysis and a Power BI or Python report.',
                  ),
                ..._items.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: WhiteCard(
                        onTap: () async {
                          if (await _showProjectSheet(context, existing: p) == true) _load();
                        },
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(p.title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                              onPressed: () async {
                                if (await confirmDelete(context, 'Delete ${p.title}?')) {
                                  await LearnService.deleteProject(p.id);
                                  _load();
                                }
                              },
                            ),
                          ]),
                          if (p.description != null) Text(p.description!, style: t.bodyMedium),
                          if (p.tools.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: p.tools
                                  .map((tl) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.secondary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(tl, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                      ))
                                  .toList(),
                            ),
                          ],
                          if (p.link != null)
                            TextButton.icon(
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              onPressed: () {
                                final u = Uri.tryParse(p.link!.startsWith('http') ? p.link! : 'https://${p.link!}');
                                if (u != null) launchUrl(u, mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Open link'),
                            ),
                        ]),
                      ),
                    )),
              ],
            ),
    );
  }
}
