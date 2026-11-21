import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../core/memory_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../core/time_utils.dart';
import '../../widgets/ui.dart';

Future<bool?> showPlaceSheet(BuildContext context, {Place? existing}) {
  final item = TextEditingController(text: existing?.item ?? '');
  final location = TextEditingController(text: existing?.location ?? '');
  Uint8List? photo;
  var ext = 'jpg';
  var removePhoto = false;
  var saving = false;

  return showAppSheet<bool>(context, existing == null ? 'Where did I keep it?' : 'Update ${existing.item}', (ctx, setS) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: item,
          autofocus: existing == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Item (e.g. baby\'s birth certificate)', prefixIcon: Icon(Icons.inventory_2_outlined)),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: location,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Where? (e.g. blue file, top wardrobe shelf)', prefixIcon: Icon(Icons.place_outlined)),
        ),
        const SizedBox(height: 12),
        if (photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(photo!, height: 180, fit: BoxFit.cover),
          )
        else if (existing?.photoPath != null && !removePhoto)
          _SignedImage(path: existing!.photoPath!, height: 180),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(photo != null || (existing?.photoPath != null && !removePhoto) ? 'Change photo' : 'Add a photo (optional)'),
              onPressed: () async {
                final p = await pickPhoto(ctx);
                if (p != null) {
                  setS(() {
                    photo = p.$1;
                    ext = p.$2;
                  });
                }
              },
            ),
          ),
          if (photo != null || (existing?.photoPath != null && !removePhoto))
            IconButton(
              onPressed: () => setS(() {
                photo = null;
                removePhoto = true;
              }),
              icon: const Icon(Icons.close),
            ),
        ]),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (item.text.trim().isEmpty || location.text.trim().isEmpty) {
                    toast(ctx, 'Add the item and where it is.');
                    return;
                  }
                  setS(() => saving = true);
                  try {
                    await MemoryService.savePlace(
                      id: existing?.id,
                      item: item.text,
                      location: location.text,
                      photo: photo,
                      photoExt: ext,
                      removePhoto: removePhoto,
                    );
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (_) {
                    setS(() => saving = false);
                    if (ctx.mounted) toast(ctx, 'Could not save. Please try again.');
                  }
                },
          child: const Text('Save'),
        ),
      ],
    );
  });
}

class PlacesView extends StatefulWidget {
  const PlacesView({super.key});
  @override
  State<PlacesView> createState() => PlacesViewState();
}

class PlacesViewState extends State<PlacesView> {
  List<Place> _items = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final r = await MemoryService.places();
      if (mounted) {
        setState(() {
          _items = r;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final q = _query.toLowerCase();
    final shown = q.isEmpty
        ? _items
        : _items.where((p) => p.item.toLowerCase().contains(q) || p.location.toLowerCase().contains(q)).toList();

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(hintText: 'Search: keys, passport, school bag...', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: 12),
          if (_items.isEmpty)
            const EmptyState(
              emoji: '🔎',
              title: 'Never search the house again',
              subtitle: 'Save where important things are kept. Your family can see this list too.',
            )
          else if (shown.isEmpty)
            EmptyState(emoji: '🤔', title: 'Nothing saved for "$_query"', subtitle: 'Try another word.'),
          ...shown.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WhiteCard(
                  onTap: () async {
                    if (await showPlaceSheet(context, existing: p) == true) load();
                  },
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    if (p.photoPath != null)
                      _SignedImage(path: p.photoPath!, height: 56, width: 56)
                    else
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.sun.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('📦', style: TextStyle(fontSize: 26)),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.item, style: const TextStyle(fontWeight: FontWeight.w900)),
                        Text('📍 ${p.location}', style: const TextStyle(color: AppColors.ink)),
                        Text(
                          'Updated ${timeAgo(p.updatedAt)}${p.updatedBy != null && p.updatedBy != Session.uid ? ' by family' : ''}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ]),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.muted),
                      onPressed: () async {
                        if (await confirmDelete(context, 'Delete ${p.item}?')) {
                          await MemoryService.deletePlace(p.id);
                          load();
                        }
                      },
                    ),
                  ]),
                ),
              )),
        ],
      ),
    );
  }
}

class _SignedImage extends StatelessWidget {
  final String path;
  final double height;
  final double? width;
  const _SignedImage({required this.path, required this.height, this.width});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: Session.signedUrl('memory-media', path),
      builder: (context, snap) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: height,
          width: width ?? double.infinity,
          child: snap.hasData
              ? Image.network(snap.data!, fit: BoxFit.cover)
              : Container(color: const Color(0xFFF3E9EC)),
        ),
      ),
    );
  }
}
