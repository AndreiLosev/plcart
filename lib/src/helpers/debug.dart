extension Debug on Object {
  Map<String, Object> debug() {
    try {
      return (this as dynamic).toMap();
    } on NoSuchMethodError {
      return {runtimeType.toString(): runtimeType};
    }
  }
}
