import 'dart:typed_data';

abstract interface class IReatainService {
  Future<void> init();
  Future<void> update(String name, Object value);
  Future<Object> select(String name, Object defaultValue);
  Future<void> close();
}

abstract interface class IErrorLogger {
  Future<void> init();
  Future<void> log(Object e, StackTrace s, [bool isFatal = false]);
  Future<void> close();
  Future<List<Map>> getAll();
  Stream<Map<String, String>> watch();
}

abstract interface class INetworkService {
  Future<void> connect();
  Future<void> disconnect();
  void subscribe(String topic);
  void listen(void Function(String topic, ByteData buffer) onData);
  void publication(String topic, ByteData buffer);
  bool isConnected();
}

abstract interface class INetworkConfig {}
