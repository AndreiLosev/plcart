import 'dart:typed_data';

abstract interface class IReatainService {
  Future<void> init();

  Future<void> update(String name, Object value);

  Future<Object> select(String name, Object defaultValue);
}

abstract interface class IErrorLogger {
  Future<void> init();
  Future<void> log(Object e, StackTrace s, [bool isFatal = false]);
}

abstract interface class INetworkService {
  Future<void> connect();
  Future<void> disconnect();
  void subscribe(String topic);
  void listen(void Function(String topic, Uint8List buffer) onData);
  void publication(String topic, Uint8List buffer);
  bool isConnected();
}
