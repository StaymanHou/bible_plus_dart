import "package:test/test.dart";

import 'package:bible_plus/bible_plus.dart';

void main() {
  var bible;

  setUp(() async {
    bible = new BiblePlus('test/files/.NIV.pdb');
    try {
        bible.loadVersionInfo();
      } on Exception {
        // Error
    }
  });

  test("bible.books returns an array of 66 books with Genesis first", () {
    var books = bible.books;
    expect(books.length, equals(66));
    expect((books[0] is BibleBook), equals(true));
    expect(books[0].fullName, equals('Genesis'));
  });

  test("BibleBook(Genesis).totalChapters returns 50", () {
    var gen = bible.books[0];
    expect(gen.totalChapters, equals(50));
  });

  test("BibleBook(Psalms).getCompleteVerse(1, 1) returns [psalms-chapter-1-verse-1-text, empty, 'Chapter 1', 'Psalm']", () {
    var gen = bible.books[18];
    expect(gen.getCompleteVerse(1, 1), equals(['Blessed is the man who does not walk in the counsel of the wicked or stand in the way of sinners or sit in the seat of mockers.', '', 'Chapter 1', 'Psalms']));
  });

  test("BibleBook(Genesis).getVerse(1, 1) returns 'In the beginning God created the heavens and the earth.'", () {
    var gen = bible.books[0];
    expect(gen.getVerse(1, 1), equals('In the beginning God created the heavens and the earth.'));
  });
}
