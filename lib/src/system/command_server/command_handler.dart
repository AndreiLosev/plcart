import 'dart:async';
import 'dart:io';

import 'package:debug_server_utils/debug_server_utils.dart';
import 'package:future_soket/future_soket.dart';
import 'package:plcart/plcart.dart';
import 'package:plcart/src/system/event_queue.dart';

class CommandHandler {
  Timer? _timer;
  final _subscriptions = <Object>[];
  final Map<String, Function> _registeredEvents;
  final Map<String, Object> _registeredTasks;
  final EventQueue _eventQueue;
  final FutureSoket _socket;
  final IErrorLogger _errorLogger;

  CommandHandler(
    Socket soket,
    this._registeredTasks,
    this._registeredEvents,
    this._eventQueue,
    this._errorLogger,
  ) : _socket = FutureSoket.fromSoket(soket) {
    _errorLogger.watch().listen((e) {
      if (_socket.isConnected()) {
        _write(ServerResponse(ResponseStatus.internalError, e));
      }
    });
  }

  Future<void> listen() async {
    while (_socket.isConnected()) {
      late final int type;
      late final dynamic payload;
      late final int id;
      try {
        (type, id, payload) = await readPacket(_socket);
      } on SocketException {
        await _socket.disconnect();
        break;
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
          CommandKind.getRegisteredEvents => _getRegisteredEvents(id),
          CommandKind.getRegisteredTasks => _getRegisteredTasks(id),
          CommandKind.runEvent =>
            _runEvent(RunEventPayload.fromMap(payload), id),
          CommandKind.subscribeTask =>
            _subscribeTask(SimplePayload(payload), _timer, _subscriptions, id),
          CommandKind.unsubscribeTask => _unsubscribeTask(
              SimplePayload(payload), _timer, _subscriptions, id),
          CommandKind.setTaskValue =>
            _setTaskValue(ForseValue.fromMap(payload), id),
          CommandKind.getAllErrors => await _getAllErrors(),
        };
      } catch (e) {
        response = ServerResponse(
          ResponseStatus.internalError,
          {"message": e.toString()},
        );
      } finally {
        _write(response, id);
      }
    }
  }

  ServerResponse _getRegisteredEvents(int id) {
    return ServerResponse.ok(
        message: {'registeredEvents': _registeredEvents.keys}, id: id);
  }

  ServerResponse _getRegisteredTasks(int id) {
    return ServerResponse.ok(
        message: {'registeredTasks': _registeredTasks.keys}, id: id);
  }

  ServerResponse _runEvent(RunEventPayload payload, int id) {
    final eventContructor = _registeredEvents[payload.eventName];
    if (eventContructor == null) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {'message': "event \"${payload.eventName}\" not found"},
        id,
      );
    }

    _eventQueue.add(Function.apply(
      eventContructor,
      payload.positionArguments,
      Map.fromEntries(payload.namedArguments.entries
          .map((i) => MapEntry(Symbol(i.key), i.value))),
    ));
    return ServerResponse.ok(id: id);
  }

  ServerResponse _subscribeTask(
      SimplePayload payload, Timer? t, List<Object> subscriptions, int id) {
    final task = _registeredTasks[payload.value];

    if (task == null) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {'message': "task \"${payload.value}\" not found"},
        id,
      );
    }

    if (subscriptions.any((t) => t == task)) {
      return ServerResponse(
        ResponseStatus.alreadySubscribed,
        {'message': "already subscribed to the task: \"$payload.value\""},
        id,
      );
    }

    subscriptions.add(task);

    if (t == null) {
      _runNotifications();
    }

    return ServerResponse.ok(id: id);
  }

  ServerResponse _unsubscribeTask(
      SimplePayload payload, Timer? t, List<Object> subscriptions, int id) {
    final task = _registeredTasks[payload.value];

    if (task == null) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {'message': "task \"${payload.value}\" not found"},
        id,
      );
    }

    if (!subscriptions.remove(task)) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {
          'message':
              "there is no subscription for the task: \"${payload.value}\""
        },
        id,
      );
    }

    if (t != null && subscriptions.isEmpty) {
      _stopNotifications();
    }

    return ServerResponse.ok(id: id);
  }

  ServerResponse _setTaskValue(ForseValue payload, int id) {
    final task = _registeredTasks[payload.task];

    if (task == null) {
      return ServerResponse(
        ResponseStatus.taskNotFound,
        {'message': "task \"${payload.task}\" not found"},
        id,
      );
    }

    try {
      (task as dynamic).setDebugValue(
        payload.field,
        payload.action.toString(),
        payload.value,
        payload.keys,
      );
    } catch (e, s) {
      return ServerResponse(
        ResponseStatus.setInvalidValueOrKey,
        {'err': e, 'st': s},
        id,
      );
    }

    return ServerResponse.ok(id: id);
  }

  Future<ServerResponse> _getAllErrors() async {
    final err = await _errorLogger.getAll();
    return ServerResponse(ResponseStatus.ok, {"err": err});
  }

  void _runNotifications() {
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final message = {};
      for (var task in _subscriptions) {
        message[task.runtimeType.toString()] = task.debug();
      }

      final packet = ServerResponse.ok(message: message);

      try {
        writePacket(_socket, packet.responseStatus.code(), 0, packet.message);
      } on SocketException {
        _stopNotifications();
      }
    });
  }

  void _stopNotifications() {
    _timer?.cancel();
    _timer = null;
  }

  void _write(ServerResponse response, [int id = 0]) {
    try {
      writePacket(
          _socket, response.responseStatus.code(), id, response.message);
    } catch (e) {
      final errRes = ServerResponse(
        ResponseStatus.internalError,
        {"message": e.toString()},
        id,
      );
      writePacket(_socket, errRes.responseStatus.code(), id, errRes.message);
    }
  }
}
