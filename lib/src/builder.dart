import 'package:auto_injector/auto_injector.dart';
import 'package:plcart/src/config.dart';
import 'package:plcart/src/contracts/property_handlers.dart';
import 'package:plcart/src/contracts/services.dart';
import 'package:plcart/src/contracts/task.dart';
import 'package:plcart/src/network_config.dart';
import 'package:plcart/src/runtime.dart';
import 'package:plcart/src/runtime_fields/network_handler.dart';
import 'package:plcart/src/runtime_fields/retain_handler.dart';
import 'package:plcart/src/system/command_server/com_server.dart';
import 'package:plcart/src/system/event_queue.dart';
import 'package:plcart/src/system/hive_error_log_service.dart';
import 'package:plcart/src/system/hive_init.dart';
import 'package:plcart/src/system/hive_retain_service.dart';
import 'package:plcart/src/system/monitoring_service.dart';
import 'package:plcart/src/system/mqtt311.dart';
import 'package:plcart/src/system/send_event.dart';
import 'package:plcart/src/system/tasks/send_network_message.dart';

class Builder {
  final _injector = AutoInjector();

  final _tasks = <String, List<String>>{};
  final _storage = <String, List<String>>{};

  final _eventsForDebug = <String, Function>{};

  final _periodicTask = <PeriodicTaskWithDep>[];
  final _eventTask = <String, List<EventTaskWhithDep>>{};
  final _allNetworkSabscribers = <INetworkSubscriber>{};

  void registerTask(Function taskConstructor) {
    final stringConstructor = taskConstructor.runtimeType.toString();

    final classString = stringConstructor.split(' => ').last;
    final params = _extractParams(stringConstructor);
    _tasks[classString] = params;
    _injector.addSingleton(taskConstructor);
  }

  void registerStorage(Function storageConstructor) {
    final stringConstructor = storageConstructor.runtimeType.toString();

    final classString = stringConstructor.split(' => ').last;
    final params = _extractParams(stringConstructor);
    _storage[classString] = params;
    _injector.addSingleton(storageConstructor);
  }

  void registerDebugEvent(Function eventConstructor) {
    final stringConstructor = eventConstructor.runtimeType.toString();

    final classString = stringConstructor.split(' => ').last;
    _eventsForDebug[classString] = eventConstructor;
  }

  void registerFactory<T>(Function constructor) {
    _injector.add<T>(constructor);
  }

  void registerSingleton<T>(Function constructor) {
    _injector.addSingleton<T>(constructor);
  }

  void registerInstance<T>(T instance) {
    _injector.addInstance(instance);
  }

  Future<Runtime> build() async {
    _builSystem();
    _buildTasks();
    await _initSystemService();
    return Runtime(
      _injector,
      _eventTask,
      _periodicTask,
      _allNetworkSabscribers,
      _createComServer(),
    );
  }

  void _buildTasks() {
    final tasksWithDepStorages = <String, List<String>>{};

    for (var storageMapEntity in _storage.entries) {
      final newDeps = <String>[];
      for (var storageDep in storageMapEntity.value) {
        if (_storage.keys.contains(storageDep)) {
          newDeps.add(storageDep);
        }
      }
      _storage[storageMapEntity.key] = newDeps;
    }

    for (var taskMapEntity in _tasks.entries) {
      final newDeps = <String>[];
      for (var taskDep in taskMapEntity.value) {
        if (_storage.keys.contains(taskDep)) {
          newDeps.add(taskDep);
        }
      }
      _tasks[taskMapEntity.key] = newDeps;
    }

    for (var taskMapEntity in _tasks.entries) {
      tasksWithDepStorages[taskMapEntity.key] = [];

      final recursive = taskMapEntity.value;
      while (recursive.isNotEmpty) {
        final storage = recursive.removeAt(0);
        tasksWithDepStorages[taskMapEntity.key]!.add(storage);
        recursive.addAll(_storage[storage] ?? []);
      }
    }

    for (var item in tasksWithDepStorages.entries) {
      final task = _injector.get(className: item.key);
      final storages =
          item.value.map((e) => _injector.get(className: e)).toList();

      final retain = [task, ...storages].whereType<IRetainProperty>().toSet();
      final monitor =
          [task, ...storages].whereType<IMonitoringProperty>().toSet();

      final subscribers =
          [task, ...storages].whereType<INetworkSubscriber>().toSet();

      _allNetworkSabscribers.addAll(subscribers);

      final publishers =
          [task, ...storages].whereType<INetworkPublisher>().toSet();

      switch (task) {
        case PeriodicTask():
          _periodicTask.add((task, retain, monitor, publishers));
        case EventTask():
          for (var event in task.eventSubscriptions) {
            if (_eventTask[event.toString()] == null) {
              _eventTask[event.toString()] = [
                (task, retain, monitor, publishers)
              ];
              continue;
            }
            _eventTask[event.toString()]!
                .add((task, retain, monitor, publishers));
          }
        default:
          throw Exception("undefinet task tipe ${task.runtimeType}");
      }
    }
  }

  void _builSystem() {
    bool useHive = false;

    if (!_injector.isAdded<Config>()) {
      _injector.addSingleton(Config.new);
    }

    if (!_injector.isAdded<INetworkConfig>()) {
      _injector.addSingleton<INetworkConfig>(MqttConfig.new);
    }

    if (!_injector.isAdded<IReatainService>()) {
      useHive = true;
      _injector.addSingleton<IReatainService>(HiveRetainService.new);
    }

    if (!_injector.isAdded<INetworkConfig>()) {
      _injector.addSingleton(MqttConfig.new);
    }

    if (!_injector.isAdded<IErrorLogger>()) {
      useHive = true;
      _injector.addSingleton<IErrorLogger>(HiveErrorLogService.new);
    }

    if (!_injector.isAdded<INetworkService>()) {
      _injector.addSingleton<INetworkService>(Mqtt311.new);
    }

    _injector.addSingleton(MonitoringService.new);
    _injector.addSingleton(EventQueue.new);
    _injector.addSingleton(RetainHandler.new);
    _injector.addSingleton(NetworkHandler.new);
    _injector.addSingleton(SendEvent.new);

    if (useHive && !_injector.isAdded<HiveInit>()) {
      _injector.addSingleton(HiveInit.new);
    }

    registerTask(PublishTask.new);

    _injector.commit();
  }

  Future<void> _initSystemService() async {
    await _injector.get<IReatainService>().init();
    await _injector.get<IErrorLogger>().init();

    for (var task in _periodicTask) {
      _injector.get<MonitoringService>().init(task.$3);
      await _injector.get<RetainHandler>().select(task.$2);
    }

    for (var tasks in _eventTask.values) {
      for (var task in tasks) {
        _injector.get<MonitoringService>().init(task.$3);
        await _injector.get<RetainHandler>().select(task.$2);
      }
    }
  }

  ComServer _createComServer() {
    final tasks = _tasks.keys
        .map((name) => MapEntry(name, _injector.get(className: name)));
    // TODO auto_events
    return ComServer(
      _eventsForDebug,
      Map.fromEntries(tasks).cast(),
      _injector.get<EventQueue>(),
    );
  }

  static List<String> _extractParams(String constructorString) {
    final params = <String>[];

    if (constructorString.startsWith('() => ')) {
      return params;
    }

    final allArgsRegex = RegExp(r'\((.+)\) => .+');

    final allArgsMatch = allArgsRegex.firstMatch(constructorString);

    var allArgs = allArgsMatch!.group(1)!;

    final hasNamedParams = RegExp(r'\{(.+)\}');
    final namedParams = hasNamedParams.firstMatch(allArgs);

    if (namedParams != null) {
      final named = namedParams.group(1)!;
      allArgs = allArgs.replaceAll('{$named}', '');

      final paramsText = _customSplit(named);

      for (final paramText in paramsText) {
        final anatomicParamText = paramText.split(' ');

        final type = anatomicParamText[anatomicParamText.length - 2];
        params.add(type);
      }
    }

    if (allArgs.isNotEmpty) {
      final paramList = _customSplit(allArgs);
      final allParam = paramList //
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .map((e) {
        return e.replaceFirst('?', '');
      }).toList();

      params.addAll(allParam);
    }

    return params;
  }

  static List<String> _customSplit(String input) {
    final parts = <String>[];
    var currentPart = '';
    var angleBracketCount = 0;

    for (final char in input.runes) {
      final charStr = String.fromCharCode(char);

      if (charStr == ',' && angleBracketCount == 0) {
        parts.add(currentPart.trim());
        currentPart = '';
      } else {
        currentPart += charStr;

        if (charStr == '<') {
          angleBracketCount++;
        } else if (charStr == '>') {
          angleBracketCount--;
        }
      }
    }

    if (currentPart.isNotEmpty && currentPart != ' ') {
      parts.add(currentPart.trim());
    }

    return parts;
  }
}
