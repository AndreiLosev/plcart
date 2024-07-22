class FTrig {
  bool _mem = false;

  bool call(bool clk) {

    final result = !clk && _mem;
    _mem = clk;

    return result;
  }
}
