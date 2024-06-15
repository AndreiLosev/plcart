extension Debug on Object {
  Map debug() {
    try {
      return (this as dynamic).toMap();
    } on NoSuchMethodError {
      return {runtimeType.toString(): runtimeType.toString()};
    }
  }
}
