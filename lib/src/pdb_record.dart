import 'dart:typed_data';

class PdbRecord {
  static const int SIZE = 4096;

  Uint8List _data;

  PdbRecord(this._data);

  Uint8List get data => _data;
}
