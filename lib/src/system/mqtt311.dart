import 'dart:async';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:plcart/plcart.dart';
import 'package:plcart/src/network_config.dart';
import 'package:typed_data/typed_data.dart';

class Mqtt311 implements INetworkService {
  final MqttConfig _config;
  late final MqttServerClient _client;

  Mqtt311(Config config) : _config = config.networkCOnfig as MqttConfig {
    _client = MqttServerClient.withPort(
      _config.host,
      _config.clientIdentifier,
      _config.port,
    );
  }

  @override
  Future<void> connect() async {
    _client
      ..logging(on: _config.log)
      ..setProtocolV311()
      ..keepAlivePeriod = _config.keepAlivePeriod.inSeconds
      ..connectTimeoutPeriod = _config.connectTimeoutPeriod.inMilliseconds
      ..autoReconnect = false
      ..connectionMessage = _getConnectMessage();

    _client.disconnect();
    await _client.connect(_config.userName, _config.password);
  }

  @override
  bool isConnected() {
    return _client.connectionStatus!.state == MqttConnectionState.connected;
  }

  @override
  Future<void> disconnect() {
    _client.disconnect();
    return Future.value();
  }

  @override
  void listen(void Function(String topic, ByteData buffer) onData) {
    _client.updates!.listen((e) {
      final topic = e.first.topic;
      final value = (e.first.payload as MqttPublishMessage).payload.message;
      onData(topic, ByteData.view(value.buffer));
    });
  }

  @override
  void subscribe(String topic) {
    _client.subscribe(topic, _config.subscriptionQot);
  }

  @override
  void publication(String topic, ByteData buffer) {
    _client.publishMessage(
      topic,
      _config.publicationQot,
      Uint8Buffer()..addAll(buffer.buffer.asUint8List()),
      retain: _config.publicationRetain.contains(topic),
    );
  }

  MqttConnectMessage _getConnectMessage() {
    final connMessage =
        MqttConnectMessage().withClientIdentifier(_config.clientIdentifier);

    if (_config.cleanSession) {
      connMessage.startClean();
    }

    final willTopic = _config.willTopic;
    final willMessage = _config.willMessage;

    if (willTopic is String && willMessage is String) {
      connMessage
          .withWillTopic(willTopic)
          .withWillMessage(willMessage)
          .withWillQos(_config.willQos);

      if (_config.willRetain) {
        connMessage.withWillRetain();
      }
    }

    return connMessage;
  }
}
