sealed class ITrig {
  bool _mem = false;
  bool _q = false;

  bool get q => _q;

  bool call(bool clk);

  Map<String, dynamic> toMap() => {
        'clk': _mem,
        'q': _q,
      };
}

class RTrig extends ITrig {
  @override
  bool call(bool clk) {
    _q = clk && !_mem;
    _mem = clk;

    return _q;
  }
}

class FTrig extends ITrig {
  @override
  bool call(bool clk) {
    _q = !clk && _mem;
    _mem = clk;

    return _q;
  }
}
