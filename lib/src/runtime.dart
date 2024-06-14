import 'dart:async';

import 'package:auto_injector/auto_injector.dart';
import 'package:plcart/src/contracts/property_handlers.dart';
import 'package:plcart/src/contracts/services.dart';
import 'package:plcart/src/contracts/task.dart';
import 'package:plcart/src/helpers/periodic_timer.dart';
import 'package:plcart/src/runtime_fields/network_handler.dart';
import 'package:plcart/src/runtime_fields/retain_handler.dart';
import 'package:plcart/src/system/command_server/com_server.dart';
import 'package:plcart/src/system/event_queue.dart';
import 'package:plcart/src/system/monitoring_service.dart';

typedef EventTaskWhithDep = (
  EventTask,
  Set<IRetainProperty>,
  Set<IMonitoringProperty>,
  Set<INetworkPublisher>
);

typedef PeriodicTaskWithDep = (
  PeriodicTask,
  Set<IRetainProperty>,
  Set<IMonitoringProperty>,
  Set<INetworkPublisher>
);

class Runtime {
  final AutoInjector _injector;

  final List<PeriodicTaskWithDep> _periodicTask;
  final Map<String, List<EventTaskWhithDep>> _eventTask;
  final Set<INetworkSubscriber> _networkSubscribers;
  final ComServer _comServer;

  final _timers = <PeriodicTimer>[];
  late final NetworkHandler _networkHandler;

  Runtime(
    this._injector,
    this._eventTask,
    this._periodicTask,
    this._networkSubscribers,
    this._comServer,
  );

  void run() {
    final retainHandler = _injector.get<RetainHandler>();
    final monitoringService = _injector.get<MonitoringService>();
    final errorLog = _injector.get<IErrorLogger>();
    _networkHandler = _injector.get<NetworkHandler>();

    _networkHandler.run(_networkSubscribers);

    for (var task in _periodicTask) {
      _timers.add(PeriodicTimer(task.$1.period, (t) {
        try {
          task.$1.execute();
          retainHandler.update(task.$2);
          monitoringService.change(task.$3);
          _networkHandler.publish(task.$4);
        } catch (e, s) {
          errorLog.log(e, s);
        }
      }, executeIfDelay: _executeIfDelay(task.$1, errorLog)));
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
          _networkHandler.publish(task.$4);
        } catch (e, s) {
          errorLog.log(e, s);
        }
      }
    });

    _comServer.run();
  }

  Future<void> stop() async {
    final f = [
      _networkHandler.stop(),
      _injector.get<IReatainService>().close(),
      _injector.get<IErrorLogger>().close(),
      _comServer.stop(),
    ];

    _injector.get<EventQueue>().close();
    for (var t in _timers) {
      t.cancel();
    }
    await Future.wait(f);
  }

  T get<T>() {
    return _injector.get<T>();
  }

  void Function() _executeIfDelay(PeriodicTask task, IErrorLogger errorLogger) => () {
    errorLogger.log(
      Exception("execution time of a periodic task is too long"),
      StackTrace.fromString("${task.runtimeType}::execute()"),
    );
  };
}
