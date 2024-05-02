import 'dart:io';

import 'package:path/path.dart';
import 'package:plcart/plcart.dart';

class Config {

  String dbPath = dirname(Platform.script.path);
  double doubleDiff = 0.1;
  int errorLogLength = 100;

  final INetworkConfig networkCOnfig;

  Config(this.networkCOnfig);
}
