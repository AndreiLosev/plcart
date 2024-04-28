import 'package:hive/hive.dart';
import 'package:plcart/src/config.dart';
import 'package:plcart/src/contracts/services.dart';
import 'package:plcart/src/system/hive_init.dart';

class HiveErrorLogService implements IErrorLogger {
  final HiveInit _init;
  final int _logLength;
  late final Box _box;

  HiveErrorLogService(HiveInit init, Config config):
    _logLength = config.errorLogLength,
    _init = init;

  @override
  Future<void> init() async {
    await _init.init();
    _box = await Hive.openBox("errorLog");
  }

  @override
  Future<void> log(Object e, StackTrace s, [bool isFatal = false]) {
    if (_box.length >= _logLength) {
      _box.deleteAt(_box.keys.first);
    }

    _box.add({'e': e, 's': s, 't': DateTime.now()});
    
    return Future.value();
  }
}
