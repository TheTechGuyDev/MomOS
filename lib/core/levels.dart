import 'dart:math';

/// Level n starts at 50 * n * (n - 1) XP: L2 = 100, L3 = 300, L4 = 600, L5 = 1000...
class LevelInfo {
  final int level;
  final int xp;
  final int levelStartXp;
  final int nextLevelXp;

  LevelInfo._(this.level, this.xp, this.levelStartXp, this.nextLevelXp);

  factory LevelInfo.fromXp(int xp) {
    var n = ((1 + sqrt(1 + 0.08 * xp)) / 2).floor();
    if (n < 1) n = 1;
    while (_start(n + 1) <= xp) {
      n++;
    }
    while (n > 1 && _start(n) > xp) {
      n--;
    }
    return LevelInfo._(n, xp, _start(n), _start(n + 1));
  }

  static int _start(int n) => 50 * n * (n - 1);

  double get progress =>
      ((xp - levelStartXp) / (nextLevelXp - levelStartXp)).clamp(0.0, 1.0);
  int get xpToNext => nextLevelXp - xp;

  String get title {
    const titles = [
      'New Bloom',
      'Rising Mum',
      'Steady Star',
      'Calm Captain',
      'Home Hero',
      'Super Planner',
      'Wonder Mum',
      'Family Legend',
      'Queen of Calm',
      'MomOS Master',
    ];
    return titles[min(level - 1, titles.length - 1)];
  }
}
