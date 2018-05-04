## Introduction

**BiblePlus** is a dart library to work with PDB bible files. It's heavily inspired by the [bibleplus java library](https://github.com/yukuku/androidbible/tree/master/BiblePlus/src/main/java/com/compactbyte/bibleplus) with improvement of implicit lazy loading and exception handling.

## Example

See `example/main.dart`

```dart
import 'package:bible_plus/bible_plus.dart';

void main() {
  BiblePlus bible = new BiblePlus('/path/to/bible.pdb');
  try {
    bible.loadVersionInfo();
  } on Exception catch (e) {
    // Error
    print(e);
  }
  // At this point we can access some basic information,
  // such as the bible version name and version info.
  // We can also have the list of book names at this point.

  // Get the version name of the bible
  String versionName = bible.versionName;
  print(versionName); // => King James Version

  // Get the version info of the bible
  String versionInfo = bible.versionInfo;
  print(versionInfo);

  // Get the total number of books in the bible
  int bookCount = bible.totalBooks;
  print(bookCount); // => 66

  // Get the BibleBook object. The line below returns Genesis
  BibleBook bGen = bible.books[0];

  // Get the full name of the book
  String fullName = bGen.fullName;
  print(fullName); // => 'Genesis'

  // Get the shot name of the book
  String shortName = bGen.shortName;
  print(shortName); // => 'Gen'

  // Get the total number of chapters in the book
  int totalChapters = bGen.totalChapters;
  print(totalChapters); // => 50

  // Get the total number of verses in the chapter
  int chapter = 1;
  int totalVerses = bGen.getTotalVerses(chapter);
  print(totalVerses); // => 31

  // Get the verse text only
  int verse = 1;
  String verseText = bGen.getVerse(chapter, verse);
  print(verseText); // => 'In the beginning...'

  // Get the chapter title, or verse title, together with
  // the verse text. See the documentation of the return
  // value in BibleBook
  List<String> sb = bGen.getCompleteVerse(chapter, verse);
  print(sb.join('\n'));
  // => 'In the beginning...\n\nChapter 1\nGenesis'
}
```

## API Doc

More detailed API documentation available [here](https://www.dartdocs.org/documentation/bible_plus/latest/)