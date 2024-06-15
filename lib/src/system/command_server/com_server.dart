import 'dart:async';
import 'dart:io';

import 'package:plcart/src/system/command_server/command_handler.dart';
import 'package:plcart/src/system/event_queue.dart';

class ComServer {
  late final ServerSocket _serverSocket;

  final Map<String, Function> _registeredEvents;
  final Map<String, Object> _registeredTasks;
  final EventQueue _eventQueue;

  ComServer(this._registeredEvents, this._registeredTasks, this._eventQueue);

  Future<void> run() async {
    _serverSocket = await ServerSocket.bind("0.0.0.0", 11223);

    _serverSocket.listen((Socket soket) {
      final handler = CommandHandler(soket, _registeredTasks, _registeredEvents, _eventQueue);
       handler.listen();
    });
  }

  Future<void> stop() async {
    await _serverSocket.close();
  }
}
