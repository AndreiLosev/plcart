import 'package:plcart/plcart.dart';
import 'package:test/test.dart';

void main() {}

class TopStorage {
  bool x1 = false;
  int x2 = 0;
  double x3 = 0;
  String x4 = '';
}

class LocalStorage1 {
  final list = <int>[];
  final TopStorage main;

  LocalStorage1(this.main);
}

class LocalStorage2 {
  final list = <double>[];
  final TopStorage main;

  LocalStorage2(this.main);

  void calc() {
    if (main.x3 > 1.5) {
      main.x1 = true;
    }
  }
}

class TestPeriodicTask1 extends PeriodicTask {
  final LocalStorage1 storage;

  TestPeriodicTask1(this.storage);

  @override
  Duration get period => Duration(milliseconds: 10);

  @override
  void execute() {
    storage.main.x2 += 1;
    storage.list.add(storage.main.x2);
  }
}

class TestPeriodicTask2 extends PeriodicTask {
  final LocalStorage2 storage;

  TestPeriodicTask2(this.storage);

  @override
  Duration get period => Duration(milliseconds: 10);

  @override
  void execute() {
    storage.calc();
    storage.main.x3 += 0.35;
    storage.list.add(storage.main.x3);
  }
}

class EventTask1 extends EventTask<Event2> {
  String str = '';

  @override
  void execute(Event2 event) {
    str = "$str-${event.v}";
  }
}

class EventTask2 extends EventTask<Event1> {
  @override
  void execute(Event1 event) {
    event.s.x4 = "${event.s.x4}-1";
  }
}

class Event1 extends Event {
  final TopStorage s;

  Event1(this.s);
}

class Event2 extends Event {
  int v;

  Event2(this.v);
}
