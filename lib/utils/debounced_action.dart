import 'dart:async';
import 'dart:ui';

class DebouncedAction {
  DebouncedAction({
    required this.action,
    this.duration = const Duration(milliseconds: 350),
  });

  final VoidCallback action;
  final Duration duration;
  Timer? _timer;

  bool get debounced => _timer != null;

  void _runAction() {
    _timer = null;
    action();
  }

  void invoke() {
    if (duration == Duration.zero) {
      _runAction();
    } else {
      _timer?.cancel();
      _timer = Timer(duration, _runAction);
    }
  }
}
