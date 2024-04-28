import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path/path.dart';
import 'package:plcart/src/config.dart';

class HiveInit {
  final String _dbPath;
  final String _dirName = 'hive';
  bool _init = false;

  HiveInit(Config config):
    _dbPath = config.dbPath;
  
  Future<void> init() async {

    if (_init) {
      return;
    }

    final path = join(_dbPath, _dirName);
    await Directory(path).create(recursive: true);
    Hive.init(path);
    _init = true;
  }
}
