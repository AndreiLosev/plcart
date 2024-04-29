import 'package:plcart/src/contracts/task.dart';
import 'package:plcart/src/system/event_queue.dart';

class SendEvent {
  final EventQueue _eventQueue;

  SendEvent(this._eventQueue);

  void call(Event e) {
    _eventQueue.add(e);
  }
}
