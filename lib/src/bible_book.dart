import 'dart:typed_data';

import 'bible_plus.dart';
import 'pdb_access.dart';
import 'pdb_record.dart';
import 'util.dart';

/// The BibleBook class represents a book in bible
class BibleBook {
  static const int _bookTextType = 0xFFFF;
  static const int _chapTextType = 0xFFFE;
  static const int _descTextType = 0xFFFD;
  static const int _versTextType = 0xFFFC;

  static const int _codeUnitOpenParentheses = 40;
  static const int _codeUnitOpenBracket = 91;
  static const int _codeUnitOpenBrace = 123;
  static const int _codeUnitDash = 45;
  static const int _codeUnitCloseParentheses = 40;
  static const int _codeUnitCloseBracket = 93;
  static const int _codeUnitCloseBrace = 125;
  static const int _codeUnitPeriod = 46;
  static const int _codeUnitComma = 44;
  static const int _codeUnitColon = 58;
  static const int _codeUnitSemiColon = 59;
  static const int _codeUnitQuestionMark = 63;
  static const int _codeUnitExclamationMark = 33;

  int _bookNum;
  int _bookIndex;
  int _totalBookRec;
  Uint8List _simpleName;
  Uint8List _complexName;
  BiblePlus _bible;
  int _totalChapters;
  bool _bookLoaded;

  Uint8List _indexData;
  Uint8List _data;
  List<int> _totalVersesAcc;
  List<int> _totalChapterCharsAcc;
  List<int> _totalVerseCharsAcc;

  List<int> _shiftLookup = const [0, 3, 2, 1];
  List<int> _verseShiftLookup = const [10, 4, 6, 8];

  /// Get the number of the book
  int get bookNumber => _bookNum;
  /// Get the total
  int get totalChapters {
    loadBook();
    return _totalChapters;
  }
  /// Get the full name of the book
  String get fullName => Util.readStringTrimZero(_complexName);
  /// Get the short name of the book
  String get shortName => Util.readStringTrimZero(_simpleName);
  Uint8List get data {
    loadBook();
    return _data;
  }

  /// Create a BibleBook instance. Only called by a BiblePlus instance when loading its data
  BibleBook(BiblePlus bible, Uint8List data, int offset) {
    _bible = bible;
    int index = 0;
    _bookNum = Util.readShort(data, offset + index);
    index += 2;
    _bookIndex = Util.readShort(data, offset + index);
    index += 2;
    _totalBookRec = Util.readShort(data, offset + index);
    if (_bookIndex + _totalBookRec > bible.header.totalRecords) throw new Exception('Incorrect book record');
    index += 2;
    _simpleName = data.sublist(offset + index, offset + index + 8);
    index += 8;
    _complexName = data.sublist(offset + index, offset + index + 32);
  }

  /// Load the basic info of the book. Only call this method explicitly when you want to eager load the book info. Otherwise this method will be lazy-loaded when necessary
  void loadBook() {
    if (_bookLoaded == true) return;

    PdbAccess access = _bible.pdbAccess;
    PdbRecord r = access.readRecord(_bookIndex);
    _indexData = r.data;

    List<PdbRecord> records = new List(_totalBookRec);
    int totalLen = 0;
    for (int i = 0; i < _totalBookRec; i++) {
      records[i] = access.readRecord(_bookIndex + i + 1);
      totalLen += records[i].data.length;
    }
    _data = new Uint8List(totalLen);
    int pos = 0;
    for (int i = 0; i < _totalBookRec; i++) {
      Uint8List data = records[i].data;
      _data.setRange(pos, pos + data.length, data);
      pos += data.length;
      access.removeFromCache(_bookIndex + i + 1);
    }

    _totalChapters = Util.readShort(_indexData, 0);
    _totalVersesAcc = new List(_totalChapters);
    int offset = 2;
    for (int i = 0; i < _totalChapters; i++) {
      _totalVersesAcc[i] = Util.readShort(_indexData, offset);
      offset += 2;
    }
    _totalChapterCharsAcc = new List(_totalChapters);
    for (int i = 0; i < _totalChapters; i++) {
      _totalChapterCharsAcc[i] = Util.readInt(_indexData, offset);
      offset += 4;
    }
    _totalVerseCharsAcc = new List(((_indexData.length - offset) / 2).floor());
    for (int i = 0; offset < _indexData.length; i++) {
      _totalVerseCharsAcc[i] = Util.readShort(_indexData, offset);
      offset += 2;
    }

    _bookLoaded = true;
  }

  /// Garbage collect the instance when you are done with it
  void close() {
    _indexData = null;
    _data = null;
    _totalVersesAcc = null;
    _totalChapterCharsAcc = null;
    _totalVerseCharsAcc = null;
  }

  /// Get complete verse content for this chapter/verse

  /// @return null on error (book not opened, invalid
  ///         chapter/verse) or the content complete content of the verse
  ///         (for each "Tags"). Index 0 contains verse (always exist),
  ///         index 1 contains pericope title (may not exist, if not
  ///         exist it will be empty string), Index 2 contains chapter
  ///         title (if exist, this will only appear in verse 1 of a
  ///         chapter), Index 3 contains book title (if exists, this will
  ///         only appear in chapter 1 verse 1 of a book.
  List<String> getCompleteVerse(int chapter, int verse) {
    loadBook();
    if (chapter < 0 || chapter > totalChapters) return null;
    if (verse < 0 || verse > getTotalVerses(chapter)) return null;
    if (_bible.isByteShifted) return _getVerseByteShifted(chapter, verse);

    List<List<String>> words = [[], [], [], []];

    int sbPos = 0; // verse
    int verseStart = _getVerseStart(chapter, verse);
    int verseLength = _getVerseLength(chapter, verse);
    int index = verseStart * 2;

    for (int i = 0; i < verseLength; i++) {
      int decWordNum = Util.readShort(_data, index);
      index += 2;
      int pos = _bible.getWordPos(decWordNum);
      List<int> r = _bible.getRepeat(pos, decWordNum);
      if (r != null) {
        for (int t in r) {
          if (t == _bookTextType || t == _chapTextType || t == _descTextType || t == _versTextType) {
            sbPos = t - _versTextType;
            continue;
          }

          String word = _bible.getWord(t);
          words[sbPos].add(word);
        }
      } else {
        String word = _bible.getWord(decWordNum);
        words[sbPos].add(word);
      }
    }

    String sepChar = _bible.sepChar;
    List<String> res = new List(4);
    res[0] = _stringFromWords(words[0], sepChar);
    res[1] = _stringFromWords(words[1], sepChar);
    res[2] = _stringFromWords(words[2], sepChar);
    res[3] = _stringFromWords(words[3], sepChar);
    return res;
  }

  /// Get only the text of the verse
  String getVerse(int chapter, int verse) {
    loadBook();
    List<String> sb = getCompleteVerse(chapter, verse);
    return sb == null ? null : sb[0];
  }

  /// Get the total number of verses of the specified chapter
  int getTotalVerses(int chapter) {
    loadBook();
    int v1 = _totalVersesAcc[chapter - 1];
    int v2 = chapter == 1 ? 0 : _totalVersesAcc[chapter - 2];
    return v1 - v2;
  }

  @override
  String toString() {
    return fullName;
  }

  String _stringFromWords(List<String> words, String sepChar) {
    if (words == null) return '';
    if (words.length == 0) return '';

    StringBuffer sb = new StringBuffer();

    String prev;
    String cur;
    for (int i = 0; i < words.length; i++) {
      cur = words[i];
      bool sep = false;
      if (prev == null || prev.length == 0) {
        // no space
      } else {
        int lastPrev = prev.codeUnitAt(prev.length - 1);
        if (lastPrev == _codeUnitOpenParentheses || lastPrev == _codeUnitOpenBracket || lastPrev == _codeUnitOpenBrace || lastPrev == _codeUnitDash || (lastPrev >= 0x2e80 && lastPrev <= 0x9fff)) {
          // no space
        } else if (cur.length == 0) {
          // no space too, exceptional case
        } else {
          int firstCur = cur.codeUnitAt(0);
          if (firstCur == _codeUnitDash || firstCur == _codeUnitCloseParentheses || firstCur == _codeUnitCloseBracket || firstCur == _codeUnitCloseBrace || firstCur == _codeUnitPeriod || firstCur == _codeUnitComma || firstCur == _codeUnitColon || firstCur == _codeUnitSemiColon || firstCur == _codeUnitQuestionMark || firstCur == _codeUnitExclamationMark || (firstCur >= 0x2e80 && firstCur <= 0x9fff)) {
            // no space
          } else {
            sep = true;
          }
        }
      }

      if (sep) sb.write(sepChar);
      sb.write(cur);
      prev = cur;
    }

    return sb.toString();
  }

  List<String> _getVerseByteShifted(int chapter, int verse) {
    int verseStart = _getVerseStart(chapter, verse);
    int verseLength = _getVerseLength(chapter, verse);
    int decShift = _shiftLookup[verseStart * 7 % 4];
    int compStart = (verseStart * 7 / 4).floor();
    List<int> decValueBuffer = new List(3);
    int index = compStart;

    switch (decShift) {
      case 1:
        decValueBuffer[1] = _data[index++];
        break;
      case 2:
      case 3:
        decValueBuffer[2] = _data[index++];
        break;
      default:
    }

    List<List<String>> words = [[], [], [], []];

    int sbPos = 0;

    outer: for (int i = 0; i < verseLength; i++) {
      if (index >= _data.length) break;
      switch (decShift) {
        case 0:
          decValueBuffer[0] = _data[index++] & 0xff;
          if (index >= _data.length) break outer;
          decValueBuffer[1] = _data[index++] & 0xff;
          decValueBuffer[2] = 0;
          break;
        case 1:
          decValueBuffer[0] = decValueBuffer[1];
          decValueBuffer[1] = _data[index++] & 0xff;
          if (index >= _data.length) break outer;
          decValueBuffer[2] = _data[index++] & 0xff;
          break;
        case 2:
          decValueBuffer[0] = decValueBuffer[2];
          decValueBuffer[1] = _data[index++] & 0xff;
          if (index >= _data.length) break outer;
          decValueBuffer[2] = _data[index++] & 0xff;
          break;
        case 3:
          decValueBuffer[0] = decValueBuffer[2];
          decValueBuffer[1] = _data[index++] & 0xff;
          decValueBuffer[2] = 0;
          break;
        default:
      }

      int value = decValueBuffer[0] << 16 | decValueBuffer[1] << 8 | decValueBuffer[2];
      value = value >> _verseShiftLookup[decShift];
      value = value & 0x3FFF;
      decShift++;
      if (decShift == 4)  decShift = 0;
      if (value > 0x3FF0) value |= 0xC000;

      int decWordNum = value;
      int pos = _bible.getWordPos(decWordNum);
      List<int> r = _bible.getRepeat(pos, decWordNum);

      if (r != null) {
        for (int j = 0; j < r.length; j++) {
          if (r[j] > 0x3FF0) r[j] |= 0xC000;
          if (r[j] == _bookTextType || r[j] == _chapTextType || r[j] == _descTextType || r[j] == _versTextType) {
            sbPos = r[j] - _versTextType;
            continue;
          }
          words[sbPos].add(_bible.getWord(r[j]));
        }
      } else {
        String word = _bible.getWord(decWordNum);
        words[sbPos].add(word);
      }
    }

    String sepChar = _bible.sepChar;
    List<String> res = new List(4);
    res[0] = _stringFromWords(words[0], sepChar);
    res[1] = _stringFromWords(words[1], sepChar);
    res[2] = _stringFromWords(words[2], sepChar);
    res[3] = _stringFromWords(words[3], sepChar);
    return res;
  }

  int _getVerseLength(int chapter, int verse) {
    int verseAcc = (chapter == 1 ? 0 : _totalVersesAcc[chapter - 2]) + verse;
    int verseLength;
    if (verse > 1) {
      verseLength = _vlen(verseAcc - 1);
    } else {
      verseLength = verseAcc == 0 ? 0 : _totalVerseCharsAcc[verseAcc - 1];
    }
    return verseLength;
  }

  int _getVerseStart(int chapter, int verse) {
    int verseAcc = (chapter == 1 ? 0 : _totalVersesAcc[chapter - 2]) + verse;
    int verseStart = chapter == 0 ? 0 : _totalChapterCharsAcc[chapter - 1];
    if (verse > 1) {
      verseStart += verseAcc == 1 ? 0 : _totalVerseCharsAcc[verseAcc - 2];
    }
    return verseStart;
  }

  int _vlen(int index) {
    int v1 = _totalVerseCharsAcc[index];
    int v2 = index == 0 ? 0 : _totalVerseCharsAcc[index - 1];
    int diff = v1 - v2;
    return diff < 0 ? 0 : diff;
  }
}
