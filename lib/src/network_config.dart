import 'package:mqtt_client/mqtt_client.dart';
import 'package:plcart/plcart.dart';

class MqttConfig implements INetworkConfig {
  String? userName;
  String? password;
  String host = "127.0.0.1";
  int port = 1883;
  bool log = false;
  Duration keepAlivePeriod = const Duration(minutes: 1);
  Duration connectTimeoutPeriod = const Duration(seconds: 5);
  String clientIdentifier = 'plcart_default_id';

  bool autoReconnect = true;

  MqttQos subscriptionQot = MqttQos.atMostOnce;
  MqttQos publicationQot = MqttQos.atMostOnce;

  Set<String> publicationRetain = {};

  String? willTopic;
  String? willMessage;
  MqttQos willQos = MqttQos.atMostOnce;

  bool cleanSession = true;

  bool willRetain = false;


}
