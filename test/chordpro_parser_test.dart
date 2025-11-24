import 'package:flutter_test/flutter_test.dart';
import 'package:nextchord/core/utils/chordpro_parser.dart';

void main() {
  group('ChordPro Metadata Extraction', () {
    test('Parse basic metadata from ChordPro file', () {
      const chordProText = '''
{title:New Sensation}
{subtitle:INXS}
{key:E}
{capo:2}
{tempo:120}
''';

      final metadata = ChordProParser.extractMetadata(chordProText);
      expect(metadata.title, 'New Sensation');
      expect(metadata.artist, 'INXS');
      expect(metadata.key, 'E');
      expect(metadata.capo, 2);
      expect(metadata.tempo, '120');
    });

    test('Handle missing metadata gracefully', () {
      const chordProText = '[C]Simple song with no metadata';
      final metadata = ChordProParser.extractMetadata(chordProText);

      expect(metadata.title, isNull);
      expect(metadata.artist, isNull);
      expect(metadata.key, isNull);
    });

    test('Parse duration into seconds', () {
      // Test MM:SS format
      final metadata1 = ChordProParser.extractMetadata('{duration:3:39}');
      expect(metadata1.duration, '3:39');
      expect(metadata1.durationInSeconds, 219); // 3*60 + 39 = 219

      // Test another MM:SS format
      final metadata2 = ChordProParser.extractMetadata('{duration:2:45}');
      expect(metadata2.durationInSeconds, 165); // 2*60 + 45 = 165

      // Test HH:MM:SS format
      final metadata3 = ChordProParser.extractMetadata('{duration:1:30:15}');
      expect(metadata3.durationInSeconds, 5415); // 1*3600 + 30*60 + 15 = 5415

      // Test missing duration
      final metadata4 = ChordProParser.extractMetadata('{title:Test}');
      expect(metadata4.durationInSeconds, isNull);
    });
  });

  group('Chord Transposition', () {
    test('Transpose simple chords up', () {
      expect(ChordProParser.transposeChord('C', 2), 'D');
      expect(ChordProParser.transposeChord('G', 2), 'A');
      expect(ChordProParser.transposeChord('A', 3), 'C');
    });

    test('Transpose simple chords down', () {
      expect(ChordProParser.transposeChord('D', -2), 'C');
      expect(ChordProParser.transposeChord('A', -2), 'G');
      expect(ChordProParser.transposeChord('C', -3), 'A');
    });

    test('Transpose complex chords preserving modifiers', () {
      expect(ChordProParser.transposeChord('Cmaj7', 2), 'Dmaj7');
      expect(ChordProParser.transposeChord('Am7', 3), 'Cm7');
      expect(ChordProParser.transposeChord('Dm7b5', 5), 'Gm7b5');
      expect(ChordProParser.transposeChord('G9', 1), 'G#9'); // G + 1 = G#
      expect(ChordProParser.transposeChord('Asus4', -2), 'Gsus4');
      expect(ChordProParser.transposeChord('C#maj7', 2),
          'D#maj7'); // Verify sharp preservation
    });

    test('Transpose slash chords', () {
      expect(ChordProParser.transposeChord('Am/G', 2), 'Bm/A');
      expect(ChordProParser.transposeChord('C/E', -1), 'B/D#');
      expect(ChordProParser.transposeChord('Dm7/C', 3), 'Fm7/D#');
    });

    test('Transpose entire ChordPro text', () {
      const original = '[C]Amazing [G]grace, how [Am]sweet the [F]sound';
      final transposed = ChordProParser.transposeChordProText(original, 2);
      expect(transposed, '[D]Amazing [A]grace, how [Bm]sweet the [G]sound');
    });
  });

  group('Structured Data Parsing', () {
    test('Parse section headers', () {
      const chordProText = '''
{verse: Verse 1}
[C]This is verse one

{chorus}
[G]This is the chorus
''';

      final lines = ChordProParser.parseToStructuredData(chordProText);

      // Find section lines
      final sections =
          lines.where((l) => l.type == ChordProLineType.section).toList();
      expect(sections.length, 2);
      expect(sections[0].section, 'Verse 1');
      expect(sections[1].section, 'Chorus');
    });

    test('Parse start_of_verse and start_of_chorus directives', () {
      const chordProText = '''
{start_of_verse: Verse 1}
[C]This is verse one
{end_of_verse}

{start_of_chorus}
[G]This is the chorus
{end_of_chorus}
''';

      final lines = ChordProParser.parseToStructuredData(chordProText);

      // Find section lines
      final sections =
          lines.where((l) => l.type == ChordProLineType.section).toList();
      expect(sections.length, 2);
      expect(sections[0].section, 'Verse 1');
      expect(sections[0].sectionType, 'start_of_verse');
      expect(sections[1].section, 'Chorus');
      expect(sections[1].sectionType, 'start_of_chorus');
    });

    test('Parse abbreviated section directives (sov, soc, sob)', () {
      const chordProText = '''
{sov: Verse 1}
[C]Verse lyrics
{eov}

{soc}
[G]Chorus lyrics
{eoc}

{sob: Bridge}
[Am]Bridge lyrics
{eob}
''';

      final lines = ChordProParser.parseToStructuredData(chordProText);

      final sections =
          lines.where((l) => l.type == ChordProLineType.section).toList();
      expect(sections.length, 3);
      expect(sections[0].section, 'Verse 1');
      expect(sections[1].section, 'Chorus');
      expect(sections[2].section, 'Bridge');
    });

    test('Parse chorus reference directive', () {
      const chordProText = '''
{start_of_chorus}
[G]This is the chorus
{end_of_chorus}

{chorus}

{chorus: Final}
''';

      final lines = ChordProParser.parseToStructuredData(chordProText);

      // Find chorus references
      final chorusRefs =
          lines.where((l) => l.type == ChordProLineType.chorusRef).toList();
      expect(chorusRefs.length, 2);
      expect(chorusRefs[0].section, 'Chorus');
      expect(chorusRefs[1].section, 'Final');
    });

    test('Parse lyrics with chords', () {
      const chordProText = '[C]Amazing [G]grace';
      final lines = ChordProParser.parseToStructuredData(chordProText);

      final lyricsLine = lines.first;
      expect(lyricsLine.type, ChordProLineType.lyrics);
      expect(lyricsLine.text, 'Amazing grace');
      expect(lyricsLine.chords.length, 2);
      expect(lyricsLine.chords[0].chord, 'C');
      expect(lyricsLine.chords[0].position, 0);
      expect(lyricsLine.chords[1].chord, 'G');
      expect(lyricsLine.chords[1].position, 8);
    });

    test('Parse comments', () {
      const chordProText = '''
# This is a comment
[C]Lyrics here
# Another comment
''';

      final lines = ChordProParser.parseToStructuredData(chordProText);
      final comments =
          lines.where((l) => l.type == ChordProLineType.comment).toList();

      expect(comments.length, 2);
      expect(comments[0].text, 'This is a comment');
      expect(comments[1].text, 'Another comment');
    });

    test('Parse tablature sections', () {
      const chordProText = '''
{sot}
e|--0--2--3--|
B|--1--3--5--|
{eot}
''';

      final lines = ChordProParser.parseToStructuredData(chordProText);
      final tabLines =
          lines.where((l) => l.type == ChordProLineType.tablature).toList();

      expect(tabLines.length, 2);
      expect(tabLines[0].text, 'e|--0--2--3--|');
    });

    test('Parse grid sections', () {
      const chordProText = '''
{start_of_grid}
| C . . . | G . . . |
| Am . . . | F . . . |
{end_of_grid}
''';

      final lines = ChordProParser.parseToStructuredData(chordProText);
      final gridLines =
          lines.where((l) => l.type == ChordProLineType.grid).toList();

      expect(gridLines.length, 2);
      expect(gridLines[0].text, '| C . . . | G . . . |');
      expect(gridLines[1].text, '| Am . . . | F . . . |');
    });

    test('Parse intro and outro sections', () {
      const chordProText = '''
{intro}
[C]Intro riff

{outro}
[G]Outro riff
''';

      final lines = ChordProParser.parseToStructuredData(chordProText);
      final sections =
          lines.where((l) => l.type == ChordProLineType.section).toList();

      expect(sections.length, 2);
      expect(sections[0].section, 'Intro');
      expect(sections[1].section, 'Outro');
    });

    test('End directives should not create section lines', () {
      const chordProText = '''
{start_of_verse}
[C]Verse lyrics
{end_of_verse}
''';

      final lines = ChordProParser.parseToStructuredData(chordProText);
      final sections =
          lines.where((l) => l.type == ChordProLineType.section).toList();

      // Should only have one section (start_of_verse), not the end_of_verse
      expect(sections.length, 1);
      expect(sections[0].section, 'Verse');
    });

    test('Handle empty lines', () {
      const chordProText = '''
[C]First line

[G]Third line
''';

      final lines = ChordProParser.parseToStructuredData(chordProText);
      expect(lines[1].type, ChordProLineType.empty);
    });
  });

  group('Render Back to ChordPro', () {
    test('Round-trip conversion', () {
      const original = '''
{title:Test Song}
{verse: Verse 1}
[C]Amazing [G]grace

{chorus}
[Am]How sweet the [F]sound
''';

      final lines = ChordProParser.parseToStructuredData(original);
      final rendered = ChordProParser.renderToChordPro(lines);

      // Parse again to verify structure is preserved
      final reparsed = ChordProParser.parseToStructuredData(rendered);
      expect(reparsed.length, lines.length);
    });
  });

  group('Extract Chords', () {
    test('Extract all chords from text', () {
      const text = '[C]Amazing [G]grace, how [Am]sweet the [F]sound';
      final chords = ChordProParser.extractChords(text);

      expect(chords, ['C', 'G', 'Am', 'F']);
    });

    test('Extract complex chords', () {
      const text = '[Cmaj7]Test [Dm7b5]chords [G#9]here';
      final chords = ChordProParser.extractChords(text);

      expect(chords, ['Cmaj7', 'Dm7b5', 'G#9']);
    });
  });

  group('Tab Auto-Completion', () {
    test('Auto-complete single tab block', () {
      const input = '''
{sot}
E|-----------|---------|---------|---------|-------|------------|
B|-----------|---------|---------|---------|-----3-|------------|
G|---4-4-2-0-|-2-------|-4-4-2-0-|-2-----4-|-4-4---|-2--2-0-----|
D|-----------|-------0-|---------|---------|-------|----------4-|
A|-----------|---------|---------|---------|-------|------------|
E|-----------|---------|---------|---------|-------|------------|

[C]Some lyrics here
''';

      final result = ChordProParser.autoCompleteTabSections(input);

      // Should have {eot} before the chord line
      expect(result.contains('{eot}'), true);
      expect(result.indexOf('{eot}') < result.indexOf('[C]'), true);
    });

    test('Auto-complete tab block with chords between', () {
      const input = '''
{sot}
E|-----------|---------|---------|---------|-------|------------|
B|-----------|---------|---------|---------|-----3-|------------|
G|---4-4-2-0-|-2-------|-4-4-2-0-|-2-----4-|-4-4---|-2--2-0-----|
D|-----------|-------0-|---------|---------|-------|----------4-|
A|-----------|---------|---------|---------|-------|------------|
E|-----------|---------|---------|---------|-------|------------|

[Em] [G] [D] [D]
E|-------|-------------|-----------|---------|''';

      final result = ChordProParser.autoCompleteTabSections(input);

      // Should have {eot} before the chord line
      expect(result.contains('{eot}'), true);
      final eotIndex = result.indexOf('{eot}');
      final chordIndex = result.indexOf('[Em]');
      expect(eotIndex < chordIndex, true);
    });

    test('Auto-complete multiple tab blocks separated by blank lines', () {
      const input = '''
{sot}
E|-----------|---------|---------|---------|-------|------------|
B|-----------|---------|---------|---------|-----3-|------------|
G|---4-4-2-0-|-2-------|-4-4-2-0-|-2-----4-|-4-4---|-2--2-0-----|
D|-----------|-------0-|---------|---------|-------|----------4-|
A|-----------|---------|---------|---------|-------|------------|
E|-----------|---------|---------|---------|-------|------------|


E|-------|-------------|-----------|---------|''';

      final result = ChordProParser.autoCompleteTabSections(input);

      // Should have {eot} at the end since both blocks are tab
      expect(result.contains('{eot}'), true);
    });

    test('Do not add {eot} if already present', () {
      const input = '''
{sot}
E|-----------|---------|---------|---------|-------|------------|
B|-----------|---------|---------|---------|-----3-|------------|
{eot}

[C]Some lyrics
''';

      final result = ChordProParser.autoCompleteTabSections(input);

      // Should not add another {eot}
      final eotCount = '{eot}'.allMatches(result).length;
      expect(eotCount, 1);
    });

    test('Handle tab block at end of file', () {
      const input = '''
{verse: Verse 1}
[C]Some lyrics

{sot}
E|-----------|---------|---------|---------|-------|------------|
B|-----------|---------|---------|---------|-----3-|------------|
G|---4-4-2-0-|-2-------|-4-4-2-0-|-2-----4-|-4-4---|-2--2-0-----|
''';

      final result = ChordProParser.autoCompleteTabSections(input);

      // Should have {eot} at the end
      expect(result.contains('{eot}'), true);
      expect(result.trim().endsWith('{eot}'), true);
    });
  });
}
