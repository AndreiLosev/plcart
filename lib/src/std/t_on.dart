class TOn {
  final _t = Stopwatch();
  bool in1 = false;
  bool q = false;
  Duration pt = Duration.zero;
  Duration et = Duration.zero;

  bool call({required bool in1, Duration? pt}) {
    if (pt != null) {
      this.pt = pt;
    }
    
    this.in1 = in1;
    
    if (this.in1 && !_t.isRunning) {
      _t.start();
    }

    q = _t.elapsed >= this.pt;
    et = _t.elapsed;

    if (q || !this.in1) {
      _t.stop();
      _t.reset();
    }

    return q;
  }
}
