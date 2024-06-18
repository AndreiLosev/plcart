sealed class Types {
  const Types();
}

class U8 extends Types {
  final bool bigEnding;
  const U8([this.bigEnding = false]);
}

class U16 extends Types {
  final bool bigEnding;
  const U16([this.bigEnding = false]);
}

class U32 extends Types {
  final bool bigEnding;
  const U32([this.bigEnding = false]);
}

class I8 extends Types {
  final bool bigEnding;
  const I8([this.bigEnding = false]);
}

class I16 extends Types {
  final bool bigEnding;
  const I16([this.bigEnding = false]);
}

class I32 extends Types {
  final bool bigEnding;
  const I32([this.bigEnding = false]);
}

class I64 extends Types {
  final bool bigEnding;
  const I64([this.bigEnding = false]);
}

class F32 extends Types {
  final bool bigEnding;
  const F32([this.bigEnding = false]);
}

class F64 extends Types {
  final bool bigEnding;
  const F64([this.bigEnding = false]);
}

class String1 extends Types {
  final String? pattern;
  String1([this.pattern]);
}

class Json extends Types {
  final String? path;
  Json([this.path]);
}

class MessagePack extends Types {
  final String? path;
  MessagePack([this.path]);
}
