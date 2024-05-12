import 'dart:typed_data';
import 'package:plcart/src/contracts/task.dart';

abstract interface class IRetainProperty {
  Map<String, Object> getRetainProperty();
  void setRetainProperties(Map<String, Object> properties);
}

abstract interface class IMonitoringProperty {
  Map<String, Object> getValues();
  Event getEvent(String key);
}

abstract interface class INetworkSubscriber {
  Set<String> getTopics();
  void setNetworkProperty(String topic,  ByteData value);
}

abstract interface class INetworkPublisher {
  Map<String, ByteData> getPublishedValues();
}
