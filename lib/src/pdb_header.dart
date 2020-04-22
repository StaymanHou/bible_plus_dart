import 'dart:typed_data';

import 'util.dart';

class PdbHeader {
  Uint8List _name;
  String _typeStr;
  String _creatorStr;
  int _totalRecords;
  Uint8List _headerData; // 78 bytes

  String get creator => _creatorStr;
  String get name => Util.readStringTrimZero(_name);
  int get totalRecords => _totalRecords;
  String get type => _typeStr;

  PdbHeader(this._headerData);

  void load() {
    int offset = 0;
    _name = _headerData.sublist(offset, offset + 32);
    offset += 32;
    offset += 2;
    offset += 2;
    offset += 4;
    offset += 4;
    offset += 4;
    offset += 4;
    offset += 4;
    offset += 4;
    _typeStr = Util.readString(
        _headerData, offset, 4); // TODO: may need double check charset
    offset += 4;
    _creatorStr = Util.readString(
        _headerData, offset, 4); // TODO: may need double check charset
    offset += 4;
    offset += 4;
    offset += 4;
    _totalRecords = Util.readShort(_headerData, offset);
  }

  @override
  String toString() {
    return 'Name: $name\n' +
        'type_str: $_typeStr\n' +
        'creator_str: $_creatorStr\n' +
        'num records: $_totalRecords\n';
  }
}
