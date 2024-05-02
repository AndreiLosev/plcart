import 'dart:async';

import 'package:auto_injector/auto_injector.dart';
import 'package:plcart/src/contracts/property_handlers.dart';
import 'package:plcart/src/contracts/services.dart';
import 'package:plcart/src/contracts/task.dart';
import 'package:plcart/src/runtime_fields/network_handler.dart';
import 'package:plcart/src/runtime_fields/retain_handler.dart';
import 'package:plcart/src/system/event_queue.dart';
import 'package:plcart/src/system/monitoring_service.dart';

typedef EventTaskWhithDep = (
  EventTask,
  Set<IRetainProperty>,
  Set<IMonitoringProperty>,
  Set<INetworkSubscriber>,
  Set<INetworkPublisher>
);

typedef PeriodicTaskWithDep = (
  PeriodicTask,
  Set<IRetainProperty>,
  Set<IMonitoringProperty>,
  Set<INetworkSubscriber>,
  Set<INetworkPublisher>
);

class Runtime {
  final List<PeriodicTaskWithDep> _periodicTask;
  final Map<String, List<EventTaskWhithDep>> _eventTask;
  final AutoInjector _injector;

  final _timers = <Timer>[];

  Runtime(this._eventTask, this._periodicTask, this._injector);

  void run() {
    final retainHandler = _injector.get<RetainHandler>();
    final monitoringService = _injector.get<MonitoringService>();
    final errorLog = _injector.get<IErrorLogger>();
    final networkHandler = _injector.get<NetworkHandler>();
    networkHandler.connect();
    for (var task in _periodicTask) {
      _timers.add(Timer.periodic(task.$1.period, (t) {
        try {
          task.$1.execute();
          retainHandler.update(task.$2);
          monitoringService.change(task.$3);
          networkHandler.publish(task.$5);
        } catch (e, s) {
          errorLog.log(e, s);
        }
      }));
    }

    _injector.get<EventQueue>().listen((e) {
      final item = _eventTask[e.runtimeType.toString()];
      if (item == null) {
        return;
      }

      for (var task in item) {
        try {
          task.$1.execute(e);
          retainHandler.update(task.$2);
          monitoringService.change(task.$3);
          networkHandler.publish(task.$5);
        } catch (e, s) {
          errorLog.log(e, s);
        }
      }
    });
  }

  void stop() {
    _injector.get<EventQueue>().close();
    for (var t in _timers) {
      t.cancel();
    }
  }

  T get<T>() {
    return _injector.get<T>();
  }
}
