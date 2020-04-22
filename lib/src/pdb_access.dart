import 'dart:typed_data';

import 'pdb_file_stream.dart';
import 'pdb_header.dart';
import 'pdb_record.dart';
import 'util.dart';

class PdbAccess {
  PdbHeader _header;
  List<PdbRecord> _records;
  Uint8List _headerData;
  PdbFileStream _iostream;

  List<int> _recordOffsets;
  List<int> _recordAttrs;

  bool _isCorrupted;

  bool get isCorrupted => _isCorrupted;
  PdbHeader get header {
    if (_header == null) {
      _headerData = _iostream.read(78);
      _header = PdbHeader(_headerData);
      header.load();
      _records = List(header.totalRecords);
      _readOffsets();

      if (_recordOffsets[_recordOffsets.length - 1] > _iostream.size) {
        _isCorrupted = true;
        throw Exception('Header is corrupted');
      }
    }
    return _header;
  }

  PdbAccess(this._iostream);

  void close() {
    _iostream.close();
    _header = null;
    if (_records != null)
      for (int i = 0; i < _records.length; i++) {
        _records[i] = null;
      }
    _records = null;
    _headerData = null;
    _iostream = null;
    _recordOffsets = null;
    _recordAttrs = null;
  }

  PdbRecord readRecord(int recNo) {
    if (_records[recNo] == null) _loadRecord(recNo);
    return _records[recNo];
  }

  void removeFromCache(int recNo) => _records[recNo] = null;

  void _loadRecord(int recNo) {
    int length;
    if (recNo < _records.length - 1) {
      length = _recordOffsets[recNo + 1] - _recordOffsets[recNo];
    } else {
      length = _iostream.size - _recordOffsets[recNo];
    }
    _iostream.seek(_recordOffsets[recNo]);
    PdbRecord pr = PdbRecord(_iostream.read(length));
    _records[recNo] = pr;
  }

  void _readOffsets() {
    int n = _header.totalRecords;
    Uint8List tempRead = _iostream.read(8 * n);
    int offset = 0;
    _recordOffsets = List(n);
    _recordAttrs = List(n);
    for (int i = 0; i < n; i++) {
      _recordOffsets[i] = Util.readInt(tempRead, offset);
      _recordAttrs[i] = tempRead[offset + 4];
      offset += 8;
    }
  }
}
