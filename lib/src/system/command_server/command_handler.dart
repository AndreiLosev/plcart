import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:debug_server_utils/debug_server_utils.dart';
import 'package:plcart/src/helpers/debug.dart';
import 'package:plcart/src/system/event_queue.dart';

class CommandHandler {
  Timer? _timer;
  final _subscriptions = <Object>[];
  final Map<String, Function> _registeredEvents;
  final Map<String, Object> _registeredTasks;
  final EventQueue _eventQueue;
  final Socket _socket;

  CommandHandler(this._socket, this._registeredTasks, this._registeredEvents,
      this._eventQueue);

  void listen() {
    _socket.listen((Uint8List data) {
      late final ServerResponse response;
      try {
        final command = parseClientCommand(data);
        response = switch (command.kind) {
          CommandKind.getRegisteredEvents => _getRegisteredTasks(),
          CommandKind.getRegisteredTasks => _getRegisteredEvents(),
          CommandKind.runEvent => _runEvent(command.payload),
          CommandKind.subscribeTask =>
            _subscribeTask(command.payload, _timer, _subscriptions),
          CommandKind.unsubscribeTask =>
            _unsubscribeTask(command.payload, _timer, _subscriptions),
          CommandKind.setTaskValue => _setTaskValue(command.payload),
        };
      } catch (e) {
        response = ServerResponse(
          ResponseStatus.internalError,
          {"message": e},
        );
      } finally {
        _socket.add(response.toBytes());
      }
    });
  }

  ServerResponse _getRegisteredEvents() {
    return ServerResponse.ok({'registeredEvents': _registeredEvents.keys});
  }

  ServerResponse _getRegisteredTasks() {
    return ServerResponse.ok({'registeredEvents': _registeredTasks.keys});
  }

  ServerResponse _runEvent(RunEventPayload payload) {
    final eventContructor = _registeredEvents[payload.eventName];
    if (eventContructor == null) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {'message': "event \"${payload.eventName}\" not found"},
      );
    }

    _eventQueue.add(Function.apply(
      eventContructor,
      payload.positionArguments,
      payload.namedArguments,
    ));
    return ServerResponse.ok();
  }

  ServerResponse _subscribeTask(
      String taskName, Timer? t, List<Object> subscriptions) {
    final task = _registeredTasks[taskName];

    if (task == null) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {'message': "task \"$taskName\" not found"},
      );
    }

    if (subscriptions.any((t) => t == task)) {
      return ServerResponse(
        ResponseStatus.alreadySubscribed,
        {'message': "already subscribed to the task: \"$taskName\""},
      );
    }

    subscriptions.add(task);

    if (t == null) {
      _runNotifications();
    }

    return ServerResponse.ok();
  }

  ServerResponse _unsubscribeTask(
      String taskName, Timer? t, List<Object> subscriptions) {
    final task = _registeredTasks[taskName];

    if (task == null) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {'message': "task \"$taskName\" not found"},
      );
    }

    if (!subscriptions.remove(task)) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {'message': "there is no subscription for the task: \"$taskName\""},
      );
    }

    if (t != null && subscriptions.isEmpty) {
      _stopNotifications();
    }

    return ServerResponse.ok();
  }

  ServerResponse _setTaskValue(SetTaskValuePayload payload) {
    final task = _registeredTasks[payload.taskName];

    if (task == null) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {'message': "task \"${payload.taskName}\" not found"},
      );
    }

    (task as dynamic).setDebugValue(
      payload.value,
      payload.index,
      payload.sIndex,
      payload.action,
    );

    return ServerResponse.ok();
  }

  void _runNotifications() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final message = {};
      for (var task in _subscriptions) {
        message[task.runtimeType.toString()] = task.debug();
      }

      _socket.add(ServerResponse.ok(message).toBytes());
    });
  }

  void _stopNotifications() {
    _timer?.cancel();
    _timer = null;
  }
}
