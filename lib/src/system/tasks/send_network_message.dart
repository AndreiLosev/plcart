import 'package:plcart/plcart.dart';
import 'package:plcart/src/system/events.dart';

class PublishTask extends EventTask<PublishEvent> {
  final INetworkService _service;

  PublishTask(this._service);

  @override
  void execute(PublishEvent event) {
    _service.publication(event.topic, event.value);
  }

  Object toMap() => [runtimeType.toString(), {}];
}
