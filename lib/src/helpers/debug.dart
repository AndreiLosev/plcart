extension Debug on Object {
  Object debug() {
    try {
      return (this as dynamic).toMap();
    } on NoSuchMethodError {
      return this;
    }
  }
}

const timeSymbols = ['ms', 's', 'm', 'h', 'd'];

Duration durationfromString(String time) {
  Map<String, int> res = {};
  final timeSymbols = ['ms', 's', 'm', 'h', 'd'];

  for (var s in timeSymbols) {
    final m = RegExp('[0-9]+$s').firstMatch(time);
    if (m == null) {
      continue;
    }

    final v = int.tryParse(m[0]!.substring(0, m[0]!.length - s.length));
    if (v is int) {
      res[s] = v;
    }

    time = time.substring(0, m.start);
    if (time.trim() == "#T") {
      break;
    }
  }

  return Duration(
    days: res['d'] ?? 0,
    hours: res['h'] ?? 0,
    minutes: res['m'] ?? 0,
    seconds: res['s'] ?? 0,
    milliseconds: res['ms'] ?? 0,
  );
}

extension ToPlcTimeString on Duration {
  String toPlcTimeStr() {
    int ms = inMilliseconds % 1000;
    int s = inSeconds % 60;
    int m = inMinutes % 60;
    int h = inHours % 24;
    int d = inDays;

    h = h % 24;
    m = m % 60;
    s = s % 60;
    ms = ms % 1000;
    final buff = StringBuffer('#T');
    if (d > 0) {
      buff.write(" ${d}d");
    }

    if (h > 0) {
      buff.write(" ${h}h");
    }

    if (m > 0) {
      buff.write(" ${m}m");
    }

    if (s > 0 || buff.length <= 3) {
      buff.write(" ${s}s");
    }

    if (ms > 0) {
      buff.write(" ${ms}ms");
    }

    return buff.toString();
  }
}
