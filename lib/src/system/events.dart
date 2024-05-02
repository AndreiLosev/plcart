import 'dart:typed_data';

import 'package:plcart/plcart.dart';

class PublishEvent extends Event {
  final String topic;
  final Uint8List value;

  PublishEvent(this.topic, this.value);
}
