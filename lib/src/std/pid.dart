import 'package:plcart/src/helpers/debug.dart';

class Pid {
  double setPoint;
  double kp;
  double tn;
  double tv;
  double yOffset;
  double yMin;
  double yMax;
  final _t = Stopwatch();
  double iAccum = 0.0;
  double _y = 0.0;
  double _err = 0.0;

  Pid({
    required this.setPoint,
    this.kp = 1,
    this.tn = 60,
    this.tv = 0,
    this.yOffset = 0,
    this.yMin = 0,
    this.yMax = 100,
  });

  double get y => _y;

  double call({
    required double actual,
    double yManual = 0,
    bool manual = false,
    bool reset = false,
  }) {
    if (reset) {
      return _reset();
    }

    if (manual) {
      return _manual(yManual);
    }

    if (!_t.isRunning) {
      iAccum = _limits(yOffset);
    }

    final period = _t.elapsed.inMilliseconds / 1000;
    _t.reset();

    final e = setPoint - actual;
    final i = _calcI(e, period);
    final d = _calcD(e, period);

    _y = _limits(kp * (e + i + d));

    return _y;
  }

  double _calcI(double e, double period) {
    if (tn < 0.001) {
      return 0;
    }

    iAccum += (e * period);
    iAccum = _limits(iAccum);

    return iAccum;
  }

  double _calcD(double e, double period) {
    if (tv < 0.001) {
      return 0;
    }

    final d = (e - _err) * tv / period;

    _err = e;

    return _limits(d);
  }

  double _reset() {
    iAccum = 0;
    _y = 0;
    _t.stop();
    _t.reset();
    return _y;
  }

  double _manual(double yManual) {
    _y = _limits(yManual);
    _t.start();
    iAccum = _y;
    return _y;
  }

  double _limits(double value) {
    return switch (value > yMax) {
      true => yMax,
      false => switch (value < yMin) {
          true => yMin,
          false => value,
        },
    };
  }

  Object toMap() => {
        'setPoint': setPoint,
        'kp': kp,
        'tn': tn,
        'tc': tv,
        'yOffset': yOffset,
        'yMin': yMin,
        'yMax': yMax,
        'err': _err,
        'iAccum': iAccum,
        '_t': _t.elapsed.toPlcTimeStr(),
        'y': _y,
      };
}
