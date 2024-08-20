import 'package:plcart/plcart.dart';

sealed class ITimer {
  final _t = Stopwatch();
  bool in1 = false;
  bool _q = false;
  Duration pt = Duration.zero;
  Duration _et = Duration.zero;

  bool get q => _q;

  Duration get et => _et;

  ITimer({Duration? pt}) {
    if (pt != null) {
      this.pt = pt;
    }
  }

  bool call({required bool in1, Duration? pt});
  Object toMap() => {
        [
          runtimeType.toString(),
          {
            'in1': in1,
            'pt': pt.toPlcTimeStr(),
            'q': _q,
            'et': et.toPlcTimeStr(),
          },
        ]
      };

  void setDebugValue(Map<String, dynamic> params) {
    switch ((params['name'], params['value'])) {
      case ('in1', bool()):
        in1 = params['value'];
      case ('pt', String()):
        pt = durationfromString(params['value']);
      default:
        throw Exception(
            "invalid value <${params['value']}> or name <${params['name']}>");
    }
  }
}

class TOn extends ITimer {
  TOn({super.pt});

  @override
  bool call({required bool in1, Duration? pt}) {
    if (pt != null) {
      this.pt = pt;
    }

    if (in1 && !this.in1) {
      _t.start();
    }

    this.in1 = in1;

    if (!this.in1) {
      _et = Duration.zero;
    }

    if (_t.isRunning) {
      _et = _t.elapsed;

      if (et >= this.pt) {
        _et = this.pt;
        _t.stop();
        _t.reset();
      }

      if (!this.in1) {
        _t.stop();
        _t.reset();
      }
    }

    _q = et == this.pt && this.in1;

    return _q;
  }
}

class TOf extends ITimer {
  TOf({super.pt});

  @override
  bool call({required bool in1, Duration? pt}) {
    if (pt != null) {
      this.pt = pt;
    }

    if (!in1 && this.in1) {
      _t.start();
    }

    this.in1 = in1;

    if (_t.isRunning) {
      _et = _t.elapsed;

      if (et >= this.pt) {
        _et = this.pt;
        _t.stop();
        _t.reset();
      }
    }

    _q = this.in1 || et < this.pt;

    return _q;
  }
}

class TP extends ITimer {
  TP({super.pt});

  @override
  bool call({required bool in1, Duration? pt}) {
    if (pt != null) {
      this.pt = pt;
    }

    if (in1 && !this.in1 && !_t.isRunning) {
      _t.start();
    }

    this.in1 = in1;

    if (_t.isRunning) {
      _et = _t.elapsed;

      if (_et >= this.pt) {
        _et = this.pt;
        _t.stop();
        _t.reset();
      }
    }

    _q = _t.isRunning;

    return _q;
  }
}
