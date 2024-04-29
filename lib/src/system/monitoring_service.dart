import 'package:plcart/src/config.dart';
import 'package:plcart/src/contracts/property_handlers.dart';
import 'package:plcart/src/system/event_queue.dart';

class MonitoringService {
  final double _doubleDiff;
  final EventQueue _eventQueue;

  MonitoringService(Config config, this._eventQueue)
      : _doubleDiff = config.doubleDiff;

  final _oldValues = <String, Map<String, Object>>{};

  void init(Iterable<IMonitoringProperty> taskAndStorages) {
    for (var taskOrStorage in taskAndStorages) {
      final key = taskOrStorage.runtimeType.toString();
      if (_oldValues[key] == null) {
        _oldValues[key] = taskOrStorage.getValues();
      }
    }
  }

  void change(Iterable<IMonitoringProperty> taskAndStorages) {
    for (var taskOrStorage in taskAndStorages) {
      final values = _oldValues[taskOrStorage.runtimeType.toString()];
      if (values == null) {
        continue;
      }

      final newValues = taskOrStorage.getValues();
      for (var key in values.keys) {
        if (_isChanged(values[key]!, newValues[key]!)) {
          _oldValues[taskOrStorage.runtimeType.toString()]![key] =
              newValues[key]!;
          _eventQueue.add(taskOrStorage.getEvent(key));
        }
      }
    }
  }

  bool _isChanged(Object oldValue, Object newValue) {
    if (oldValue is double && newValue is double) {
      return (oldValue - newValue).abs() > _doubleDiff;
    } else {
      return oldValue != newValue;
    }
  }
}
