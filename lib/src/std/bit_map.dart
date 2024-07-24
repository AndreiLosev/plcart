extension BitMap on int {
  bool operator [](int pos) {
    final x = this >> pos;
    return x & 1 == 1;
  }

  int bit(int pos, bool bit) {
    final x = 1 << pos;
    if (bit) {
      return this | x;
    }

    return this[pos] ? this ^ x : this;
  }
}
