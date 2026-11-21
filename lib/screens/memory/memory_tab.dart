import 'package:material_ui/material_ui.dart';

import '../../widgets/ui.dart';
import 'notes_view.dart';
import 'places_view.dart';
import 'reminders_view.dart';

class MemoryTab extends StatefulWidget {
  const MemoryTab({super.key});
  @override
  State<MemoryTab> createState() => _MemoryTabState();
}

class _MemoryTabState extends State<MemoryTab> {
  String _view = 'reminders';
  final _remindersKey = GlobalKey<RemindersViewState>();
  final _placesKey = GlobalKey<PlacesViewState>();
  final _notesKey = GlobalKey<NotesViewState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _view == 'notes'
          ? null
          : FloatingActionButton(
              onPressed: () async {
                if (_view == 'reminders') {
                  if (await showReminderSheet(context) == true) _remindersKey.currentState?.load();
                } else {
                  if (await showPlaceSheet(context) == true) _placesKey.currentState?.load();
                }
              },
              child: const Icon(Icons.add),
            ),
      body: Column(children: [
        const TabHeader(title: 'Memory', subtitle: 'Let the app remember, so you don\'t have to'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'reminders', label: Text('Reminders')),
                ButtonSegment(value: 'places', label: Text('Where is it?')),
                ButtonSegment(value: 'notes', label: Text('Brain dump')),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.first),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: ['reminders', 'places', 'notes'].indexOf(_view),
            children: [
              RemindersView(key: _remindersKey),
              PlacesView(key: _placesKey),
              NotesView(key: _notesKey),
            ],
          ),
        ),
      ]),
    );
  }
}
