import 'package:flutter/foundation.dart';

/// Bumped whenever something earns XP so the Home tab can refresh.
class AppEvents {
  static final statsChanged = ValueNotifier<int>(0);
  static void bump() => statsChanged.value++;
}
