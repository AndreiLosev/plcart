import 'dart:io';

import 'package:path/path.dart';

class Config {

  String dbPath = dirname(Platform.script.path);
  double doubleDiff = 0.1;
  int errorLogLength = 100;
}
