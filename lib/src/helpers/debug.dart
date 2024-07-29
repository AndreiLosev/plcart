extension Debug on Object {
  Object debug() {
    try {
      return (this as dynamic).toMap();
    } on NoSuchMethodError {
      return this;
    }
  }
}
