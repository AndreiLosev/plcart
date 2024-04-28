import 'package:hive/hive.dart';
import 'package:plcart/src/config.dart';
import 'package:plcart/src/contracts/services.dart';
import 'package:plcart/src/system/hive_init.dart';

class HiveRetainService implements IReatainService {
  final HiveInit _init;
  final double _doubleDiff;
  late final Box _box;

  HiveRetainService(Config config, HiveInit init):
    _init = init,
    _doubleDiff = config.doubleDiff;

  @override
  Future<void> init() async {
    _init.init();
    _box = await Hive.openBox('retain');
  }

  @override
  Future<Object> select(String name, Object defaultValue) {
    final value = _box.get(name);

    if (value == null) {
      _box.put(name, defaultValue);
      return Future.value(defaultValue);
    } else {
      defaultValue = value;
      return Future.value(defaultValue);
    }
  }

  @override
  Future<void> update(String name, Object value) {
    if (value is double) {
      final double diff = _box.get(name) - value; 

      if (diff.abs() > _doubleDiff) {
        _box.put(name, value);
      }

      return Future.value();
    }

    if (_box.get(name) != value) {
      _box.put(name, value);
    }

    return Future.value();
  }
}
