import 'dart:typed_data';

import 'package:plcart/src/helpers/types.dart';

class Watch {
  const Watch();
}

class Generate {
  const Generate();
}

class Retain {
  final String? toBytesFactory;

  const Retain([this.toBytesFactory]);
}

class Monitoring {
  final Type eventType;
  final List<String>? eventParams;
  final Function()? eventFactory;

  const Monitoring(this.eventType, {this.eventParams, this.eventFactory});
}

class NetworkSubscriber {
  final String topic;
  final Types? type;
  final dynamic Function(ByteData)? factory;

  const NetworkSubscriber(this.topic, {this.type, this.factory});
}

class NetworkPublisher {
  final String topic;
  final Types? type;
  final ByteData Function(dynamic)? factory;
  const NetworkPublisher(this.topic, {this.type, this.factory});
}
