import 'dart:convert';
import 'dart:typed_data';

class Util {
  static String readStringTrimZero(Uint8List data) {
    int end = data.length - 1;
    while (end >= 0) {
      if (data[end] != 0) break;
      end--;
    }
    end++;

    Utf8Decoder converter = Utf8Decoder(allowMalformed: true);
    return converter.convert(data, 0, end);
  }

  static String readString(Uint8List data, int offset, int length) {
    Utf8Decoder converter = Utf8Decoder(allowMalformed: true);
    return converter.convert(data, offset, offset + length);
  }

  static int readShort(Uint8List data, int offset) {
    return ((data[offset] & 0xff) << 8) | (data[offset + 1] & 0xff);
  }

  static int readInt(Uint8List data, int offset) {
    return (((data[offset] & 0xff) << 24) |
        ((data[offset + 1] & 0xff) << 16) |
        ((data[offset + 2] & 0xff) << 8) |
        (data[offset + 3] & 0xff));
  }
}
