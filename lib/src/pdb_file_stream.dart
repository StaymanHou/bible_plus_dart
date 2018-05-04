import 'dart:io';
import 'dart:typed_data';

class PdbFileStream {
  RandomAccessFile _fis;
  int _pos;

  PdbFileStream(String filepath) {
    File file = new File(filepath);
    _fis = file.openSync();
    _pos = 0;
  }

  int get currentPosition => _pos;
  int get size => _fis.lengthSync();

  Uint8List read(int nbytes) {
    _pos += nbytes;
    return _fis.readSync(nbytes);
  }

  void seek(int position) {
    _fis.setPositionSync(position);
    _pos = position;
  }

  void skip(int nbytes) {
    seek(_pos + nbytes);
  }

  void close() {
    _fis.closeSync();
  }
}