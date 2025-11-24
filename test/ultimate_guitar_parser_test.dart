import 'package:flutter_test/flutter_test.dart';
import 'package:nextchord/core/utils/ultimate_guitar_parser.dart';

void main() {
  group('UltimateGuitarParser', () {
    test('converts simple chord tags to ChordPro format', () {
      const input = '[ch]G[/ch]  [ch]C[/ch]  [ch]D[/ch]';
      const expected = '[G]  [C]  [D]';

      final result = UltimateGuitarParser.convertToChordPro(input);

      expect(result, equals(expected));
    });

    test('converts section markers to ChordPro format', () {
      const input = '[Intro]\n\n[Verse]\nSome lyrics\n\n[Chorus]\nMore lyrics';

      final result = UltimateGuitarParser.convertToChordPro(input);

      expect(result, contains('{comment: Intro}'));
      expect(result, contains('{start_of_verse}'));
      expect(result, contains('{start_of_chorus}'));
    });

    test('converts tab blocks with chords and lyrics', () {
      const input = '''[tab][ch]G[/ch]   [ch]C[/ch]
Amazing grace[/tab]''';

      final result = UltimateGuitarParser.convertToChordPro(input);

      expect(result, contains('[G]'));
      expect(result, contains('[C]'));
      expect(result, contains('Amazing grace'));
    });

    test('handles real Ultimate Guitar format example', () {
      const input = '''Crazy - Icehouse (Man Of Colours, 1987)

[Intro]

[ch]G/F[/ch]  [ch]G/F[/ch]   [ch]F[/ch]     [ch]G/B[/ch]    x2

[Verse]
[tab][ch]G/F[/ch]   [ch]F[/ch]                   [ch]G/B[/ch]            
        I've got a pocket   full of holes  [/tab]
[tab][ch]G/F[/ch]   [ch]F[/ch]                        [ch]G/B[/ch]
        Head in the clouds the king of fools[/tab]

[Chorus]
[tab]            [ch]C[/ch]                     [ch]Csus2[/ch] [ch]C[/ch]             [ch]Am[/ch]           [ch]Asus4[/ch]  [ch]Am[/ch]
Well you've got to be crazy baby (oh    oh) to want a guy like me (oh     oh)[/tab]''';

      final result = UltimateGuitarParser.convertToChordPro(input);

      // Check that sections are converted
      expect(result, contains('{comment: Intro}'));
      expect(result, contains('{start_of_verse}'));
      expect(result, contains('{start_of_chorus}'));

      // Check that chords are converted
      expect(result, contains('[G/F]'));
      expect(result, contains('[F]'));
      expect(result, contains('[G/B]'));
      expect(result, contains('[C]'));

      // Check that lyrics are preserved
      expect(result, contains('I\'ve got a pocket'));
      expect(result, contains('Head in the clouds'));
      expect(result, contains('Well you\'ve got to be crazy baby'));

      // Check that [tab] tags are removed
      expect(result, isNot(contains('[tab]')));
      expect(result, isNot(contains('[/tab]')));
      expect(result, isNot(contains('[ch]')));
      expect(result, isNot(contains('[/ch]')));
    });

    test('extracts metadata from first line', () {
      const input = 'Crazy - Icehouse (Man Of Colours, 1987)\n\nSome content';

      final metadata = UltimateGuitarParser.extractMetadata(input);

      expect(metadata['title'], equals('Icehouse'));
      expect(metadata['artist'], equals('Crazy'));
    });

    test('handles empty input', () {
      const input = '';

      final result = UltimateGuitarParser.convertToChordPro(input);

      expect(result, equals(''));
    });

    test('normalizes line endings', () {
      const input = '[ch]G[/ch]\r\n[ch]C[/ch]\r\n[ch]D[/ch]';

      final result = UltimateGuitarParser.convertToChordPro(input);

      // Should have normalized line endings
      expect(result, isNot(contains('\r')));
    });
  });
}
