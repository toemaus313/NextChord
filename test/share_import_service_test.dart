import 'package:flutter_test/flutter_test.dart';
import 'package:nextchord/services/import/share_import_service.dart';
import 'package:nextchord/services/import/content_type_detector.dart';

void main() {
  group('ContentTypeDetector', () {
    group('Tab content detection', () {
      test('identifies tab content with multiple tab lines', () {
        const tabContent = '''
e|----------|------------|----------------|
B|----------|------------|----------3--3--|
G|----------|------------|----------------|
D|----------|------------|----------------|
A|----------|------------|----------------|
E|----------|------------|----------------|
        ''';
        expect(ContentTypeDetector.isTabContent(tabContent), isTrue);
      });

      test('identifies tab content with lyrics between', () {
        const mixedContent = '''
e|----------|------------|----------------|
B|----------|------------|----------3--3--|
G|----------|------------|----------------|

This is the verse section

e|---0--2--3--|---0--2--3--|---0--2--3--|
B|---1--3--5--|---1--3--5--|---1--3--5--|
G|---0--2--4--|---0--2--4--|---0--2--4--|
        ''';
        expect(ContentTypeDetector.isTabContent(mixedContent), isTrue);
      });

      test('rejects chord-over-lyric content', () {
        const chordContent = '''
[C]Hello [G]world, [Am]how are [F]you
[C]I'm [G]fine [Am]thank [F]you
[C]Nice [G]weather [Am]we're [F]having
        ''';
        expect(ContentTypeDetector.isTabContent(chordContent), isFalse);
      });

      test('rejects plain lyrics', () {
        const lyricsContent = '''
Hello world, this is a song
With multiple lines of text
And no tab notation at all
Just regular song lyrics
        ''';
        expect(ContentTypeDetector.isTabContent(lyricsContent), isFalse);
      });
    });
  });

  group('ShareImportService', () {
    late ShareImportService service;

    setUp(() {
      service = ShareImportService();
    });

    group('UG tab conversion', () {
      test('wraps tab blocks in {sot}/{eot} tags', () {
        const input = '''
Title: Test Song
Artist: Test Artist

e|----------|------------|----------------|
B|----------|------------|----------3--3--|
G|----------|------------|----------------|

This is a verse section

e|---0--2--3--|---0--2--3--|---0--2--3--|
B|---1--3--5--|---1--3--5--|---1--3--5--|
G|---0--2--4--|---0--2--4--|---0--2--4--|

More lyrics here
        ''';

        final result = service.convertUltimateGuitarTabExportToChordPro(input);

        expect(result, contains('{sot}'));
        expect(result, contains('{eot}'));
        expect(result, contains('e|----------|------------|----------------|'));
        expect(result, contains('This is a verse section'));
        expect(result, contains('More lyrics here'));

        // Verify structure: {sot} tab block {eot}
        final lines = result.split('\n');
        expect(lines, contains('{sot}'));
        expect(lines, contains('{eot}'));

        // Check that tab lines are between {sot} and {eot}
        final firstSotIndex = lines.indexOf('{sot}');
        final firstEotIndex = lines.indexOf('{eot}');
        expect(firstSotIndex, lessThan(firstEotIndex));
        expect(lines[firstSotIndex + 1], contains('e|----------|'));
      });

      test('handles single tab block', () {
        const input = '''
e|---0--2--3--|---0--2--3--|---0--2--3--|
B|---1--3--5--|---1--3--5--|---1--3--5--|
G|---0--2--4--|---0--2--4--|---0--2--4--|
        ''';

        final result = service.convertUltimateGuitarTabExportToChordPro(input);

        expect(result, startsWith('{sot}'));
        expect(result, endsWith('{eot}'));
        expect(result.split('\n'),
            contains('e|---0--2--3--|---0--2--3--|---0--2--3--|'));
      });

      test('preserves empty lines within tab blocks', () {
        final input = '''
e|----------|------------|----------------|

B|----------|------------|----------3--3--|

G|----------|------------|----------------|
        ''';

        final result = service.convertUltimateGuitarTabExportToChordPro(input);

        expect(result, contains('{sot}'));
        expect(result, contains('{eot}'));
        final lines = result.split('\n');
        final sotIndex = lines.indexOf('{sot}');
        final eotIndex = lines.indexOf('{eot}');

        // Check that empty lines are preserved within the tab block
        final tabBlockLines = lines.sublist(sotIndex + 1, eotIndex);
        expect(tabBlockLines, contains(''));
      });
    });
  });
}
