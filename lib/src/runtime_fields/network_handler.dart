import 'package:plcart/plcart.dart';

class NetworkHandler {
  final INetworkService _service;
  final _taskTopics = <String, Set<INetworkSubscriber>>{};
  final IErrorLogger _errorLogger;

  NetworkHandler(this._service, this._errorLogger, );

  Future<void> connect() async {
    await _service.connect();
  }

  Future<void> disconnect() async {
    await _service.disconnect();
  }

  void publish(Iterable<INetworkPublisher> taskAndStorages) {
    for (var taskOrStorage in taskAndStorages) {
      for (var item in taskOrStorage.getPublishedValues().entries) {
        try {
          _service.publication(item.key, item.value);
        } catch (e, s) {
          _errorLogger.log(e, s);
        }
      }
    }
  }

  Future<void> subscribe(Iterable<INetworkSubscriber> taskAndStorages) async {
    await _pendingConnection();
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

  Future<void> listen() async {
    await _pendingConnection();
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

  Future<void> _pendingConnection() async {
    while (!_service.isConnected()) {
      await Future.delayed(Duration(seconds: 1));
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
}
