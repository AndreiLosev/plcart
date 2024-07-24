class Pid {
  double setPoint = 0.0;
  double kp = 0.0;
  double tn = 0.0;
  double tv = 0.0;
  double yOffset = 0.0;
  double yMin = 0.0;
  double yMax = 0.0;
  double err = 0.0;
  final _t = Stopwatch();
  double iAccum = 0.0;
}
