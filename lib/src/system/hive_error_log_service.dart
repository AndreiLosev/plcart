import 'package:hive/hive.dart';
import 'package:plcart/src/config.dart';
import 'package:plcart/src/contracts/services.dart';
import 'package:plcart/src/system/hive_init.dart';

class HiveErrorLogService implements IErrorLogger {
  final HiveInit _init;
  final int _logLength;
  late final Box _box;

  HiveErrorLogService(HiveInit init, Config config)
      : _logLength = config.errorLogLength,
        _init = init;

  @override
  Future<void> init() async {
    await _init.init();
    _box = await Hive.openBox("system_$runtimeType");
  }

  @override
  Future<void> log(Object e, StackTrace s, [bool isFatal = false]) {
    try {
      if (_box.length >= _logLength) {
        _box.deleteAt(_box.keys.first);
      }

      _box.add({
        'e': e.toString(),
        's': s.toString(),
        't': DateTime.now().toString()
      });
    } catch (e) {
      //TODO:
      print("error loger: $e");
    }
    return Future.value();
  }

  @override
  Stream<Map<String, String>> watch() {
    return _box
        .watch()
        .where((e) => e.value != null)
        .map((e) => (e.value as Map).cast<String, String>());
  }

  @override
  Future<List<Map>> getAll() {
    return Future.value(_box.values.toList().cast());
  }

  @override
  Future<void> close() {
    _box.close();
    return Future.value();
  }
}
