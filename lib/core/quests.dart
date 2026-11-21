class Quest {
  final String key;
  final String emoji;
  final String title;
  final String hint;
  const Quest(this.key, this.emoji, this.title, this.hint);
}

const questPool = <Quest>[
  Quest('water_8', '💧', 'Drink 8 glasses of water', 'Keep a bottle close while feeding'),
  Quest('stretch', '🧘', 'Stretch for 5 minutes', 'Neck, shoulders and back'),
  Quest('fresh_air', '🌤️', 'Get 10 minutes of fresh air', 'A short walk or the balcony counts'),
  Quest('gratitude', '🙏', 'Write one thing you are grateful for', 'Big or small'),
  Quest('eat_breakfast', '🍳', 'Eat a proper breakfast', 'You need fuel too'),
  Quest('nap', '😴', 'Rest when the baby naps', 'Even 20 minutes helps'),
  Quest('call_friend', '📞', 'Call or text a friend', 'Stay connected'),
  Quest('story_time', '📖', 'Read a story with your big girl', '10 minutes of together time'),
  Quest('tidy_one', '🧺', 'Tidy one small spot', 'Just one drawer or shelf'),
  Quest('plan_tomorrow', '📝', 'Plan 3 things for tomorrow', 'Write them down tonight'),
  Quest('screen_break', '📵', 'Take a 30-minute phone break', 'Rest your eyes and mind'),
  Quest('fruit', '🍎', 'Eat a fruit', 'A quick, easy snack'),
  Quest('breathe', '🌬️', 'Do 1 minute of deep breathing', 'In for 4, hold 4, out for 6'),
  Quest('music', '🎶', 'Listen to a song you love', 'Dance with the girls'),
  Quest('skin_care', '🧴', 'Do a small self-care routine', 'Face, hair or a warm bath'),
  Quest('learn_10', '🎓', 'Learn something for 10 minutes', 'The Learn tab is coming soon'),
];

/// Picks 4 quests for the given day, the same for the whole day.
List<Quest> questsForDay(DateTime day) {
  final seed = day.year * 10000 + day.month * 100 + day.day;
  final list = List<Quest>.from(questPool);
  var s = seed;
  for (var i = list.length - 1; i > 0; i--) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    final j = s % (i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
  return list.take(4).toList();
}

/// Today's date in Lagos (UTC+1), matching the server.
DateTime lagosToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 1));
  return DateTime(now.year, now.month, now.day);
}
