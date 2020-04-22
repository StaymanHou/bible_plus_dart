import 'dart:typed_data';

import 'bible_book.dart';
import 'pdb_access.dart';
import 'pdb_file_stream.dart';
import 'pdb_header.dart';
import 'pdb_record.dart';
import 'util.dart';

/// The BiblePlus class represents a bible
class BiblePlus {
  Uint8List _versionName;
  Uint8List _versionInfo;
  Uint8List _sepChar;
  int _versionAttr;
  int _wordIndex;
  int _totalWordRec;
  PdbHeader _header;

  bool _wordIndexLoaded;
  static final int _infByteNotShifted = 0x02;

  PdbAccess _pdbAccess;
  List<BibleBook> _books;

  Uint8List _wordData;
  List<int> _wordLength;
  List<int> _totalWord;
  List<bool> _compressed;
  List<int> _byteAcc;

  static final int _bookRecSize = 46;

  int _failReason;

  static const int SUCCESS = 0;
  static const int ERR_NOT_PDB_FILE = 1;
  static const int ERR_NOT_BIBLE_PLUS_FILE = 2;
  static const int ERR_FILE_CORRUPTED = 3;

  /// Get all books in the bible
  List<BibleBook> get books => _books;

  /// Get the total number of books in the bible
  int get totalBooks => _books.length;

  /// Get the reason why it failed to load the bible if any
  int get failReason => _failReason;

  /// Get the version name of the bible
  String get versionName => Util.readStringTrimZero(_versionName);

  /// Get the version info of the bible
  String get versionInfo => Util.readStringTrimZero(_versionInfo);
  String get sepChar => Util.readStringTrimZero(_sepChar);
  PdbHeader get header => _header;
  PdbAccess get pdbAccess => _pdbAccess;
  bool get isByteShifted {
    return (_versionAttr & _infByteNotShifted) == 0;
  }

  List<bool> get compressed {
    loadWordIndex();
    return _compressed;
  }

  /// Create a BiblePlus instance of the file specified by the filepath
  BiblePlus(String filepath) {
    _pdbAccess = PdbAccess(PdbFileStream(filepath));
  }

  /// Load the basic info of the bible. You would probably always call this method after initializing a BiblePlus instance
  void loadVersionInfo() {
    _failReason = SUCCESS;

    try {
      _header = _pdbAccess.header;
    } on Exception {
      _failReason = ERR_NOT_PDB_FILE;
      throw Exception('ERR_NOT_PDB_FILE');
    }

    if (_pdbAccess.isCorrupted == true) {
      _failReason = ERR_FILE_CORRUPTED;
      throw Exception('ERR_FILE_CORRUPTED');
    }

    if (_header.type != 'bibl') {
      _failReason = ERR_NOT_BIBLE_PLUS_FILE;
      throw Exception('ERR_NOT_BIBLE_PLUS_FILE');
    }

    PdbRecord version = _pdbAccess.readRecord(0);

    Uint8List data = version.data;

    int index = 0;
    _versionName = data.sublist(index, index + 16);
    index += 16;
    _versionInfo = data.sublist(index, index + 128);
    index += 128;
    _sepChar = data.sublist(index, index + 1);
    index++;
    _versionAttr = data[index] & 0xff;
    index++;
    _wordIndex = Util.readShort(data, index);
    index += 2;
    _totalWordRec = Util.readShort(data, index);
    index += 2;
    if (_wordIndex + _totalWordRec >= _header.totalRecords) {
      _failReason = ERR_FILE_CORRUPTED;
      throw Exception('ERR_FILE_CORRUPTED');
    }
    int totalBooks = Util.readShort(data, index);
    index += 2;
    if (totalBooks < 0) {
      _failReason = ERR_FILE_CORRUPTED;
      throw Exception('ERR_FILE_CORRUPTED');
    }

    _books = List(totalBooks);

    for (int i = 0; i < totalBooks; i++) {
      if (index + _bookRecSize > data.length) {
        _failReason = ERR_FILE_CORRUPTED;
        throw Exception('ERR_FILE_CORRUPTED');
      }

      try {
        _books[i] = BibleBook(this, data, index);
      } on Exception {
        _failReason = ERR_FILE_CORRUPTED;
        throw Exception('ERR_FILE_CORRUPTED');
      }

      index += _bookRecSize;
    }

    _pdbAccess.removeFromCache(0);
  }

  /// Load the word index of the pdb file. Only call this method explicitly when you want to eager load the word index. Otherwise this method will be lazy-loaded when necessary
  void loadWordIndex() {
    if (_wordIndexLoaded == true) return;

    PdbRecord r = _pdbAccess.readRecord(_wordIndex);
    int index = 0;
    Uint8List indexData = r.data;
    int totalIndexes = Util.readShort(indexData, index);
    index += 2;
    _wordLength = List(totalIndexes);
    _totalWord = List(totalIndexes);
    _compressed = List(totalIndexes);

    for (int i = 0; i < totalIndexes; i++) {
      _wordLength[i] = Util.readShort(indexData, index);
      index += 2;
      _totalWord[i] = Util.readShort(indexData, index);
      index += 2;
      _compressed[i] = indexData[index++] != 0;
      index++;
    }

    int totalByteAcc = 0;
    _byteAcc = List(totalIndexes + 1);
    _byteAcc[0] = 0;
    for (int i = 1; i <= totalIndexes; i++) {
      totalByteAcc += _totalWord[i - 1] * _wordLength[i - 1];
      _byteAcc[i] = totalByteAcc;
    }

    List<PdbRecord> records = List(_totalWordRec);
    int totalLen = 0;
    for (int i = 0; i < _totalWordRec; i++) {
      records[i] = _pdbAccess.readRecord(_wordIndex + i + 1);
      totalLen += records[i].data.length;
    }

    _wordData = Uint8List(totalLen);
    int l = 0;
    for (int i = 0; i < _totalWordRec; i++) {
      Uint8List d = records[i].data;
      _wordData.setRange(l, l + d.length, d);
      l += d.length;
      _pdbAccess.removeFromCache(_wordIndex + i + 1);
    }

    _wordIndexLoaded = true;
  }

  /// Garbage collect the instance when you are done with it
  void close() {
    _wordData = null;
    _wordLength = null;
    _totalWord = null;
    _compressed = null;
    _byteAcc = null;

    if (_books != null) {
      for (int i = 0; i < _books.length; i++) {
        if (_books[i] != null) {
          _books[i].close();
          _books[i] = null;
        }
      }
    }
    if (_pdbAccess != null) {
      _pdbAccess.close();
      _pdbAccess = null;
    }
  }

  List<int> getRepeat(int pos, int wordNum) {
    loadWordIndex();
    int repeat;
    List<int> result;
    if (wordNum < 0xFFF0) {
      if (pos == 0 || _compressed[pos]) {
        int len = _wordLength[pos];
        repeat = (len / 2).floor();
        if (repeat == 0) return null;

        result = List(repeat);
        int st = _getWordIndex(pos, wordNum);
        for (int i = 0; i < repeat; i++) {
          result[i] = Util.readShort(_wordData, st);
          st += 2;
        }
        return result;
      }
    }
    return [wordNum];
  }

  String getWord(int wordNum) {
    loadWordIndex();
    int pos = getWordPos(wordNum);
    int index = _getWordIndex(pos, wordNum);
    int len = _wordLength[pos];
    if (index == -1) return '';
    return readString(index, len);
  }

  int getWordPos(int wordNum) {
    loadWordIndex();
    int relNum = wordNum - 1;
    for (int i = 0; i < _totalWord.length; i++) {
      int totalWord = _totalWord[i];
      if (relNum < totalWord) {
        return i;
      } else {
        relNum -= totalWord;
      }
    }
    return 0;
  }

  int _getWordIndex(int pos, int wordNum) {
    int relNum = wordNum - 1;
    int decWordIndex = 0;
    for (int i = 0; i <= pos; i++) {
      int totalWord = _totalWord[i];
      if (relNum < totalWord) {
        int decWordLen = _wordLength[i];
        decWordIndex = _byteAcc[i] + relNum * decWordLen;
        break;
      } else {
        relNum -= totalWord;
      }
    }
    return decWordIndex;
  }

  String readString(int index, int len) {
    return Util.readString(_wordData, index, len);
  }
}
