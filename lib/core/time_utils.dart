String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) {
    final m = d.inMinutes % 60;
    return m == 0 ? '${d.inHours}h ago' : '${d.inHours}h ${m}m ago';
  }
  if (d.inDays == 1) return 'yesterday';
  return '${d.inDays} days ago';
}

String durationText(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

String clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
}

String shortDate(DateTime t) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${months[t.month - 1]} ${t.year}';
}

String ageText(DateTime birth) {
  final now = DateTime.now();
  var months = (now.year - birth.year) * 12 + now.month - birth.month;
  if (now.day < birth.day) months--;
  if (months < 1) {
    final weeks = now.difference(birth).inDays ~/ 7;
    return weeks <= 1 ? '${now.difference(birth).inDays} days old' : '$weeks weeks old';
  }
  if (months < 24) return months == 1 ? '1 month old' : '$months months old';
  final years = months ~/ 12;
  return '$years years old';
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
