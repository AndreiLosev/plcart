import 'dart:async';

class PeriodicTimer implements Timer {
  bool _lock = false;
  late final Timer _timer;
  final void Function()? _executeIfDelay;

  PeriodicTimer(Duration period, FutureOr<void> Function(Timer) fn,
      {void Function()? executeIfDelay})
      : _executeIfDelay = executeIfDelay {
    _timer = Timer.periodic(period, (timer) {
      if (_lock) {
        _executeIfDelay?.call();
        return;
      }

      _lock = true;

      final r = fn(timer);

      if (r is Future) {
        r.then((_) {
          _lock = false;
        });
      } else {
        _lock = false;
      }
    });
  }

  @override
  bool get isActive => _timer.isActive;

  @override
  void cancel() => _timer.cancel();

  @override
  int get tick => _timer.tick;
}
