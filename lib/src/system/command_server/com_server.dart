import 'dart:async';
import 'dart:io';

import 'package:plcart/plcart.dart';
import 'package:plcart/src/system/command_server/command_handler.dart';
import 'package:plcart/src/system/event_queue.dart';

class ComServer {
  late final ServerSocket _serverSocket;

  final Map<String, Function> _registeredEvents;
  final Map<String, Object> _registeredTasks;
  final EventQueue _eventQueue;
  final IErrorLogger _errorLogger;

  ComServer(this._registeredEvents, this._registeredTasks, this._eventQueue,
      this._errorLogger);

  Future<void> run() async {
    _serverSocket = await ServerSocket.bind("0.0.0.0", 11223);

    _serverSocket.listen((Socket soket) {
      final handler = CommandHandler(soket, _registeredTasks, _registeredEvents,
          _eventQueue, _errorLogger);
      handler.listen();
    });
  }

  Future<void> stop() async {
    await _serverSocket.close();
  }
}
