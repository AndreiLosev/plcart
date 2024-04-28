import 'package:auto_injector/auto_injector.dart';
import 'package:plcart/src/config.dart';
import 'package:plcart/src/contracts/property_handlers.dart';
import 'package:plcart/src/contracts/services.dart';
import 'package:plcart/src/contracts/task.dart';
import 'package:plcart/src/runtime.dart';
import 'package:plcart/src/runtime_fields/retain_handler.dart';
import 'package:plcart/src/system/event_queue.dart';
import 'package:plcart/src/system/hive_error_log_service.dart';
import 'package:plcart/src/system/hive_init.dart';
import 'package:plcart/src/system/hive_retain_service.dart';
import 'package:plcart/src/system/monitoring_service.dart';

class Builder {
  final _container = AutoInjector();

  final _tasks = <String, List<String>>{};
  final _storage = <String, List<String>>{};

  final _periodicTask = <PeriodicTaskWithDep>[];
  final _eventTask = <String, List<EventTaskWhithDep>>{};

  void registerTask(Function taskConstructor) {
    final stringConstructor = taskConstructor.runtimeType.toString();

    final classString = stringConstructor.split(' => ').last;
    final params = _extractParams(stringConstructor);
    _tasks[classString] = params;
    _container.addSingleton(taskConstructor);
  }

  void registerStorage(Function storageConstructor) {
    final stringConstructor = storageConstructor.runtimeType.toString();

    final classString = stringConstructor.split(' => ').last;
    final params = _extractParams(stringConstructor);
    _storage[classString] = params;
    _container.addSingleton(storageConstructor);
  }

  void registerFactory<T>(Function constructor) {
    _container.add<T>(constructor);
  }

  void registerSingleton<T>(Function constructor) {
    _container.addSingleton<T>(constructor);
  }

  void registerInstance<T>(T instance) {
    _container.addInstance(instance);
  }

  Future<Runtime> build() async {
    _container.commit();
    _builSystem();
    _buildTasks();
    await _initSystemService();
    return Runtime(_eventTask, _periodicTask, _container);
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
      final task = _container.get(className: item.key);
      final storages =
          item.value.map((e) => _container.get(className: e)).toList();

      final retain = [task, ...storages].whereType<IRetainProperty>().toSet();
      final monitor =
          [task, ...storages].whereType<IMonitoringProperty>().toSet();

      switch (task) {
        case PeriodicTask():
          _periodicTask.add((task, retain, monitor));
        case EventTask():
          for (var event in task.eventSubscriptions) {
            if (_eventTask[event.runtimeType.toString()] == null) {
              _eventTask[event.runtimeType.toString()] = [
                (task, retain, monitor)
              ];
              continue;
            }
            _eventTask[event.runtimeType.toString()]!
                .add((task, retain, monitor));
          }
        default:
          throw Exception("undefinet task tipe ${task.runtimeType}");
      }
    }
  }

  void _builSystem() {
    if (!_container.isAdded<Config>()) {
      _container.addSingleton(Config.new);
    }
    if (!_container.isAdded<IReatainService>()) {
      _container.addSingleton<IReatainService>(HiveRetainService.new);
    }

    if (!_container.isAdded<IErrorLogger>()) {
      _container.addSingleton(HiveErrorLogService.new);
    }

    _container.addSingleton(MonitoringService.new);
    _container.addSingleton(EventQueue.new);

    if (_container.get<IReatainService>() is HiveRetainService ||
        _container.get<IErrorLogger>() is HiveErrorLogService) {
      _container.addSingleton(HiveInit.new);
    }
  }

  Future<void> _initSystemService() async {
    await _container.get<IReatainService>().init();
    await _container.get<IErrorLogger>().init();

    for (var task in _periodicTask) {
      _container.get<MonitoringService>().init(task.$3);
      await _container.get<RetainHandler>().select(task.$2);
    }

    for (var tasks in _eventTask.values) {
      for (var task in tasks) {
        _container.get<MonitoringService>().init(task.$3);
        await _container.get<RetainHandler>().select(task.$2);
      }
    }
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
