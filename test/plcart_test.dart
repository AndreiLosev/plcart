import 'dart:async';

import 'package:plcart/plcart.dart';
import 'package:test/test.dart';

void main() {
  test("test", () async {
    var builder = Builder()
      ..registerTask(TestPeriodicTask1.new)
      ..registerTask(TestPeriodicTask2.new)
      ..registerTask(EventTask1.new)
      ..registerTask(EventTask2.new)
      ..registerStorage(TopStorage.new)
      ..registerStorage(LocalStorage1.new)
      ..registerStorage(LocalStorage2.new);

    var runtime = await builder.build();
    runtime.run();

    await Future.delayed(Duration(milliseconds: 55), () => runtime.stop());

    var pt1 = runtime.get<TestPeriodicTask1>();
    var pt2 = runtime.get<TestPeriodicTask2>();
    var et1 = runtime.get<EventTask1>();

    expect(pt1.storage.main.x2, 5);
    expect(pt1.storage.list, [1, 2, 3, 4, 5]);
    expect((pt2.storage.main.x3 * 100).round(), 175);
    expect(pt2.storage.list.map((e) => (e * 100).round()),
        [35, 70, 105, 140, 175]);
    expect(pt1.storage.main.x1, false);
    expect(et1.str, "-1-4");
    expect(pt2.storage.main.x4, "-1-1-1-1-1");

    builder = Builder()
      ..registerTask(TestPeriodicTask1.new)
      ..registerTask(TestPeriodicTask2.new)
      ..registerTask(EventTask1.new)
      ..registerTask(EventTask2.new)
      ..registerStorage(TopStorage.new)
      ..registerStorage(LocalStorage1.new)
      ..registerStorage(LocalStorage2.new);

    runtime = await builder.build();
    runtime.run();

    await Future.delayed(Duration(milliseconds: 55), () => runtime.stop());

    pt1 = runtime.get<TestPeriodicTask1>();
    pt2 = runtime.get<TestPeriodicTask2>();
    et1 = runtime.get<EventTask1>();

    expect(pt1.storage.main.x2, 10);
    expect(pt1.storage.list, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect((pt2.storage.main.x3 * 100).round(), 350);
    expect(pt2.storage.list.map((e) => (e * 100).round()),
        [210, 245, 280, 315, 350]);
    expect(pt1.storage.main.x1, false);
    expect(et1.str, "-1-4");
    expect(pt2.storage.main.x4, "-1-1-1-1-1-1");
  });
}

class TopStorage implements IRetainProperty, IMonitoringProperty {
  bool x1 = false;
  int x2 = 0;
  double x3 = 0;
  String x4 = '';

  @override
  void setRetainProperties(Map<String, Object> properties) {
    x2 = properties['TopStorage::x2'] as int;
    x3 = properties["TopStorage::x3"] as double;
  }

  @override
  Map<String, Object> getRetainProperty() {
    return {
      "TopStorage::x2": x2,
      "TopStorage::x3": x3,
    };
  }

  @override
  Map<String, Object> getValues() {
    return {
      "TopStorage::x1": x1,
      "TopStorage::x3": x3,
    };
  }

  @override
  Event getEvent(String key) {
    switch (key) {
      case "TopStorage::x1":
        return Event2(x2);
      case "TopStorage::x3":
        return Event1(this);
      default:
        throw Exception("undefinet");
    }
  }
}

class LocalStorage1 implements IRetainProperty {
  final list = <int>[];
  final TopStorage main;

  LocalStorage1(this.main);

  @override
  Map<String, Object> getRetainProperty() {
    return {
      'LocalStorage1::list': list,
    };
  }

  @override
  void setRetainProperties(Map<String, Object> properties) {
    list.addAll((properties['LocalStorage1::list']! as List).cast());
  }
}

class LocalStorage2 {
  final list = <double>[];
  final TopStorage main;

  LocalStorage2(this.main);

  void calc() {
    if (main.x3 < 0.9) {
      main.x1 = true;
    } else {
      main.x1 = false;
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

class EventTask1 extends EventTask<Event2> implements IRetainProperty {
  String str = '';

  @override
  void execute(Event2 event) {
    str = "$str-${event.v}";
  }

  @override
  void setRetainProperties(Map<String, Object> properties) {
    str = properties['EventTask1::str'] as String;
  }

  @override
  Map<String, Object> getRetainProperty() {
    return {"EventTask1::str": str};
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
