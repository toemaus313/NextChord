import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:troubadour/core/utils/ug_text_converter.dart';

void main() {
  group('UGTextConverter', () {
    test('converts shaniatab sample without dropping tabs', () {
      final samplePath = File('examples/shaniatab.tab');
      expect(samplePath.existsSync(), isTrue,
          reason: 'examples/shaniatab.tab should exist for this test');

      final input = samplePath.readAsStringSync();
      final result = UGTextConverter.convertToChordPro(input);
      final metadata = result['metadata'] as Map<String, String>;
      final chordPro = result['chordpro'] as String;

      expect(metadata['title'], 'Any Man Of Mine');
      expect(metadata['artist'], 'Shania Twain');

      expect(chordPro, contains('{title: Any Man Of Mine}'));
      final tabBlockPattern =
          RegExp(r'\{sot\}\s*\ne\|[-0-9|]+', multiLine: true);
      expect(
        tabBlockPattern.hasMatch(chordPro),
        isTrue,
        reason: 'Tab block should be wrapped in {sot}/{eot}',
      );
      expect(
        chordPro,
        contains('B|-1/3--1---0-1-0--------------------|'),
        reason: 'Tab content should be preserved',
      );
      expect(chordPro, contains('{eot}'));
    });
  });
}
