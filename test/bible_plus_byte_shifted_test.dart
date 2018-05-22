import "package:test/test.dart";

import 'package:bible_plus/bible_plus.dart';

void main() {
  var bible;

  setUp(() async {
    bible = new BiblePlus('test/files/.KJV.pdb');
    try {
        bible.loadVersionInfo();
      } on Exception {
        print('error opening the book');
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

  test("BibleBook(Psalms).getCompleteVerse(1, 1) returns [psalms-chapter-1-verse-1-text, empty, 'Kapitel 1', 'Psalm']", () {
    var gen = bible.books[18];
    expect(gen.getCompleteVerse(1, 1), equals(['Blessed is the man that walketh not in the counsel of the ungodly, nor standeth in the way of sinners, nor sitteth in the seat of the scornful.', '', 'Kapitel 1', 'Psalm']));
  });

  test("BibleBook(Genesis).getVerse(1, 1) returns 'In the beginning God created the heaven and the earth.'", () {
    var gen = bible.books[0];
    expect(gen.getVerse(1, 1), equals('In the beginning God created the heaven and the earth.'));
  });
}
