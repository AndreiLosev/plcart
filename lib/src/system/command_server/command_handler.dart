import 'dart:async';
import 'dart:io';

import 'package:debug_server_utils/debug_server_utils.dart';
import 'package:future_soket/future_soket.dart';
import 'package:plcart/src/helpers/debug.dart';
import 'package:plcart/src/system/event_queue.dart';

class CommandHandler {
  Timer? _timer;
  final _subscriptions = <Object>[];
  final Map<String, Function> _registeredEvents;
  final Map<String, Object> _registeredTasks;
  final EventQueue _eventQueue;
  final FutureSoket _socket;

  CommandHandler(
    Socket soket,
    this._registeredTasks,
    this._registeredEvents,
    this._eventQueue,
  ) : _socket = FutureSoket.fromSoket(soket);

  Future<void> listen() async {
    late final int type;
    late final dynamic payload;
    while (_socket.isConnected()) {
      try {
        (type, payload) = await readPacket(_socket);
      } catch (_) {
        if (_socket.isConnected()) {
          continue;
        } else {
          break;
        }
      }

      late final ServerResponse response;
      try {
        response = switch (type.toCommandKind()) {
          CommandKind.getRegisteredEvents => _getRegisteredEvents(),
          CommandKind.getRegisteredTasks => _getRegisteredTasks(),
          CommandKind.runEvent => _runEvent(RunEventPayload.fromMap(payload)),
          CommandKind.subscribeTask =>
            _subscribeTask(SimplePayload(payload), _timer, _subscriptions),
          CommandKind.unsubscribeTask =>
            _unsubscribeTask(SimplePayload(payload), _timer, _subscriptions),
          CommandKind.setTaskValue =>
            _setTaskValue(SetTaskValuePayload(payload)),
        };
      } catch (e) {
        response = ServerResponse(
          ResponseStatus.internalError,
          {"message": e.toString()},
        );
      } finally {
        writePacket(_socket, response.responseStatus.code(), response.message);
      }
    }
  }

  ServerResponse _getRegisteredEvents() {
    return ServerResponse.ok({'registeredEvents': _registeredEvents.keys});
  }

  ServerResponse _getRegisteredTasks() {
    return ServerResponse.ok({'registeredTasks': _registeredTasks.keys});
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
      Map.fromEntries(payload.namedArguments.entries
          .map((i) => MapEntry(Symbol(i.key), i.value))),
    ));
    return ServerResponse.ok();
  }

  ServerResponse _subscribeTask(
      SimplePayload payload, Timer? t, List<Object> subscriptions) {
    final task = _registeredTasks[payload.value];

    if (task == null) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {'message': "task \"${payload.value}\" not found"},
      );
    }

    if (subscriptions.any((t) => t == task)) {
      return ServerResponse(
        ResponseStatus.alreadySubscribed,
        {'message': "already subscribed to the task: \"$payload.value\""},
      );
    }

    subscriptions.add(task);

    if (t == null) {
      _runNotifications();
    }

    return ServerResponse.ok();
  }

  ServerResponse _unsubscribeTask(
      SimplePayload payload, Timer? t, List<Object> subscriptions) {
    final task = _registeredTasks[payload.value];

    if (task == null) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {'message': "task \"${payload.value}\" not found"},
      );
    }

    if (!subscriptions.remove(task)) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {
          'message':
              "there is no subscription for the task: \"${payload.value}\""
        },
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

      final packet = ServerResponse.ok(message);

      writePacket(_socket, packet.responseStatus.code(), packet.message);
    });
  }

  void _stopNotifications() {
    _timer?.cancel();
    _timer = null;
  }
}
