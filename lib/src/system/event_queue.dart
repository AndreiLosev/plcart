import 'dart:async';

import 'package:plcart/src/contracts/task.dart';

class EventQueue {
  final _queue = StreamController<Event>.broadcast();

  void add(Event event) {
    if (_queue.isClosed) {
      return;
    }
    _queue.add(event);
  }

  void listen(void Function(Event) onEvent) {
    _queue.stream.listen(onEvent);
  }

  void close() {
    _queue.close();
  }
}
