import 'dart:async';

import 'package:plcart/plcart.dart';
import 'package:plcart/src/helpers/periodic_timer.dart';

class NetworkHandler {
  final INetworkService _service;
  final _taskTopics = <String, Set<INetworkSubscriber>>{};
  final IErrorLogger _errorLogger;
  bool _run = false;
  late Timer _coonectionTimer;
  final _reConnectQueue = StreamController<bool>();
  final Duration _reconnectTimeout = Duration(seconds: 5);
  bool _connectionLock = false;

  NetworkHandler(
    this._service,
    this._errorLogger,
  );

  Future<void> run(Iterable<INetworkSubscriber> taskAndStorages) async {
    _run = true;

    _reConnectQueue.stream.listen((_) async {
      if (_connectionLock) {
        return;
      }
      _connectionLock = true;
      await _connect(taskAndStorages);
      _connectionLock = false;
    });

    _reConnectQueue.add(true);

    _coonectionTimer = PeriodicTimer(_reconnectTimeout, (_) async {
      if (_service.isConnected() || !_run) {
        return;
      }

      _reConnectQueue.add(true);
    });
  }

  Future<void> stop() async {
    _run = false;
    _coonectionTimer.cancel();
    _reConnectQueue.close();
    await _service.disconnect();
  }

  void publish(Iterable<INetworkPublisher> taskAndStorages) {
    for (var taskOrStorage in taskAndStorages) {
      for (var item in taskOrStorage.getPublishedValues().entries) {
        try {
          _service.publication(item.key, item.value);
        } catch (e, s) {
          _errorLogger.log(e, s);
          if (!_service.isConnected()) {
            _reConnectQueue.add(true);
          }
        }
      }
    }
  }

  Future<void> _subscribe(Iterable<INetworkSubscriber> taskAndStorages) async {
    for (var taskOrStorage in taskAndStorages) {
      for (var topic in taskOrStorage.getTopics()) {
        _addtaskToTopic(topic, taskOrStorage);
        try {
          _service.subscribe(topic);
        } catch (e, s) {
          _errorLogger.log(e, s);
        }
      }
    }
  }

  Future<void> _listen() async {
    _service.listen((topic, buffer) {
      final taskAndStorages = _matchTopic(topic);
      for (var taskOrStorage in taskAndStorages) {
        taskOrStorage.setNetworkProperty(topic, buffer);
      }
    });
  }

  void _addtaskToTopic(String topic, INetworkSubscriber taskOrStorage) {
    if (_taskTopics[topic] == null) {
      _taskTopics[topic] = {taskOrStorage};
    } else {
      _taskTopics[topic]!.add(taskOrStorage);
    }
  }

  Iterable<INetworkSubscriber> _matchTopic(String topic) {
    if (_taskTopics[topic] != null) {
      return _taskTopics[topic]!;
    }

    final regexTopics = _taskTopics.keys
        .where((e) => e.endsWith("#") || e.contains("+"))
        .map((e) => (
              e.endsWith("#")
                  ? e.replaceFirst('#', ".*")
                  : e.replaceAll('+', '.+'),
              e
            ))
        .where((e) => RegExp(e.$1).hasMatch(topic))
        .map((e) => e.$2)
        .first;

    return _taskTopics[regexTopics]!;
  }

  Future<void> _connect(Iterable<INetworkSubscriber> taskAndStorages) async {
    try {
      await _service.connect();
      await _subscribe(taskAndStorages);
      _listen();
    } catch (e, s) {
      _errorLogger.log(e, s);
    }
  }
}
