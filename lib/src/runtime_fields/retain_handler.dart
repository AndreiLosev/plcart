import 'package:plcart/src/contracts/property_handlers.dart';
import 'package:plcart/src/contracts/services.dart';

class RetainHandler {
  final IReatainService _reatainService;

  RetainHandler(this._reatainService);

  Future<void> select(Iterable<IRetainProperty> taskAndStorages) async {
    for (var taskOrStorage in taskAndStorages) {
      final values = <String, Object>{};
      for (var item in taskOrStorage.getRetainProperty().entries) {
        final value = await _reatainService.select(item.key, item.value);
        values[item.key] = value;
      }
      taskOrStorage.setRetainProperties(values);
    }
  }

  Future<void> update(Iterable<IRetainProperty> taskAndStorages) async {
    for (var taskOrStorage in taskAndStorages) {
      for (var item in taskOrStorage.getRetainProperty().entries) {
        await _reatainService.update(item.key, item.value);
      }
    }
  }
}
