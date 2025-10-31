import 'package:flutter/foundation.dart';

/// Global animation/video pause state.
class AnimationService {
  // true = paused, false = playing
  static final ValueNotifier<bool> paused = ValueNotifier<bool>(false);

  static void toggle() {
    paused.value = !paused.value;
  }
}
