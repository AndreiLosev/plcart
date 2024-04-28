import 'package:hive/hive.dart';
import 'package:plcart/src/config.dart';

class HiveInit {
  final String _dbPath;
  bool _init = false;

  HiveInit(Config config):
    _dbPath = config.dbPath;
  
  void init() {

    if (_init) {
      return;
    }

    Hive.init(_dbPath);
    _init = true;
  }
}
