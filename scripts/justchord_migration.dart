import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

/// CLI options for JustChord -> NextChord migration
class CliOptions {
  final String libraryPath;
  final bool whatIf;

  const CliOptions({
    required this.libraryPath,
    required this.whatIf,
  });
}

/// Entry point for JustChord migration
///
/// Usage:
///   dart justchord_migration.dart -whatif --file path/to/library.json
///   dart justchord_migration.dart --file path/to/library.json
void main(List<String> args) async {
  final cliOptions = _parseCliOptions(args);
  final libraryPath = _resolveLibraryPath(cliOptions.libraryPath);
  final dbPath = await _findDatabasePath();

  if (dbPath == null) {
    stderr.writeln('ERROR: Could not locate nextchord_db.sqlite');
    exit(1);
  }

  // Read and parse library.json
  final libraryFile = File(libraryPath);
  if (!await libraryFile.exists()) {
    stderr.writeln('ERROR: library.json not found at: $libraryPath');
    exit(1);
  }

  final jsonString = await libraryFile.readAsString();
  final data = jsonDecode(jsonString) as Map<String, dynamic>;

  final songsJson = (data['songs'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .toList() ??
      <Map<String, dynamic>>[];
  final playlistsJson = (data['playlists'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .toList() ??
      <Map<String, dynamic>>[];
  final midiLibraryMessagesJson =
      (data['midiLibraryMessages'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          <Map<String, dynamic>>[];

  if (songsJson.isEmpty) {
    stderr.writeln(
        'WARNING: No songs found in library.json ("songs" array is empty).');
  }
  if (playlistsJson.isEmpty) {
    stderr.writeln(
        'WARNING: No playlists found in library.json ("playlists" array is empty).');
  }
  if (midiLibraryMessagesJson.isEmpty) {
    stderr.writeln(
        'WARNING: No MIDI profiles found in library.json ("midiLibraryMessages" array is empty).');
  }

  if (songsJson.isEmpty ||
      playlistsJson.isEmpty ||
      midiLibraryMessagesJson.isEmpty) {
    stderr.writeln(
        'One or more required collections (songs, playlists, midiLibraryMessages) are missing or empty.');
  }

  // Prepare ID mappings (old JustChord ID -> new NextChord UUID)
  final uuid = const Uuid();
  final Map<String, String> songIdMap = {};
  final Map<String, String> playlistIdMap = {};
  final Map<String, String> midiProfileIdMap = {};

  for (final song in songsJson) {
    final oldId = song['id'] as String?;
    if (oldId != null && oldId.isNotEmpty) {
      songIdMap[oldId] = uuid.v4();
    }
  }

  for (final playlist in playlistsJson) {
    final oldId = playlist['id'] as String?;
    if (oldId != null && oldId.isNotEmpty) {
      playlistIdMap[oldId] = uuid.v4();
    }
  }

  for (final profile in midiLibraryMessagesJson) {
    final oldId = profile['id'] as String?;
    if (oldId != null && oldId.isNotEmpty) {
      midiProfileIdMap[oldId] = uuid.v4();
    }
  }

  // Open database
  final db = sqlite3.open(dbPath);

  try {
    // Basic sanity check: ensure core tables exist
    _ensureCoreTablesExist(db);

    final report = _MigrationReport();

    // Import MIDI profiles first so we can link songs to profiles
    _processMidiProfiles(
      db: db,
      midiProfilesJson: midiLibraryMessagesJson,
      midiProfileIdMap: midiProfileIdMap,
      whatIf: cliOptions.whatIf,
      report: report,
    );

    // Import songs (no tags, no JustChord UUIDs)
    _processSongs(
      db: db,
      songsJson: songsJson,
      songIdMap: songIdMap,
      midiProfileIdMap: midiProfileIdMap,
      whatIf: cliOptions.whatIf,
      report: report,
    );

    // Import playlists as setlists, using new song IDs
    _processPlaylists(
      db: db,
      playlistsJson: playlistsJson,
      songIdMap: songIdMap,
      playlistIdMap: playlistIdMap,
      whatIf: cliOptions.whatIf,
      report: report,
    );

    // Print summary report
    stdout.writeln('');
    stdout.writeln('==== JustChord Migration Report ====');
    stdout.writeln(
        'Mode      : ${cliOptions.whatIf ? 'WHAT-IF (dry run, no changes written)' : 'EXECUTE (changes applied)'}');
    stdout.writeln('Database  : $dbPath');
    stdout.writeln('Source    : $libraryPath');
    stdout.writeln('');

    report.printToStdout();

    if (songsJson.isEmpty ||
        playlistsJson.isEmpty ||
        midiLibraryMessagesJson.isEmpty) {
      stderr.writeln(
          'NOTE: At least one of songs/playlists/midiLibraryMessages was missing or empty. Review warnings above.');
    }
  } finally {
    db.dispose();
  }
}

CliOptions _parseCliOptions(List<String> args) {
  String libraryPath = 'library.json';
  bool whatIf = false;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    switch (arg) {
      case '-h':
      case '--help':
        _printUsage();
        exit(0);
      case '-whatif':
      case '--whatif':
        whatIf = true;
        break;
      case '--file':
        if (i + 1 < args.length) {
          libraryPath = args[++i];
        } else {
          stderr.writeln('ERROR: --file requires a path argument');
          _printUsage();
          exit(1);
        }
        break;
      default:
        if (arg.startsWith('-')) {
          stderr.writeln('ERROR: Unknown argument: $arg');
          _printUsage();
          exit(1);
        }
        break;
    }
  }

  return CliOptions(
    libraryPath: libraryPath,
    whatIf: whatIf,
  );
}

void _printUsage() {
  stdout.writeln('JustChord -> NextChord migration');
  stdout.writeln('');
  stdout.writeln('Usage:');
  stdout.writeln('  dart justchord_migration.dart [options]');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln(
      '  --file <path>   Path to library.json (default: library.json)');
  stdout.writeln(
      '  -whatif         Dry run: report only, do not write to database');
  stdout.writeln('  --whatif        Same as -whatif');
}

String _resolveLibraryPath(String libraryPath) {
  if (p.isAbsolute(libraryPath)) {
    return libraryPath;
  }

  final scriptDir = p.dirname(Platform.script.toFilePath());
  final examplesDir = p.join(p.dirname(scriptDir), 'examples');

  final possiblePaths = <String>[
    p.join(scriptDir, libraryPath),
    p.join(examplesDir, libraryPath),
    libraryPath,
  ];

  for (final path in possiblePaths) {
    if (File(path).existsSync()) {
      return path;
    }
  }

  return libraryPath;
}

Future<String?> _findDatabasePath() async {
  final env = Platform.environment;
  final homeDir = env['HOME'] ?? env['USERPROFILE'];

  if (homeDir == null) {
    return null;
  }

  final possiblePaths = <String>[];
  Directory? deepSearchRoot;

  if (Platform.isMacOS) {
    possiblePaths.addAll([
      '$homeDir/Library/Containers/us.antonovich.nextchord/Data/Documents/nextchord_db.sqlite',
      '$homeDir/Documents/nextchord_db.sqlite',
    ]);
  } else if (Platform.isWindows) {
    final userProfile = env['USERPROFILE'] ?? homeDir;
    possiblePaths.addAll([
      '$userProfile\\Documents\\nextchord_db.sqlite',
      '$userProfile\\Documents\\*.sqlite',
      '$userProfile\\AppData\\Local\\nextchord_db.sqlite',
      '$userProfile\\AppData\\Roaming\\nextchord_db.sqlite',
    ]);
    deepSearchRoot = Directory('$userProfile\\Documents');
  } else {
    possiblePaths.addAll([
      '$homeDir/nextchord_db.sqlite',
      '$homeDir/Documents/nextchord_db.sqlite',
    ]);
  }

  possiblePaths.add('nextchord_db.sqlite');

  if (Platform.isWindows &&
      deepSearchRoot != null &&
      await deepSearchRoot.exists()) {
    await for (final entity
        in deepSearchRoot.list(recursive: false, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.sqlite')) {
        return entity.path;
      }
    }

    await for (final entity
        in deepSearchRoot.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.sqlite')) {
        return entity.path;
      }
    }
  }

  for (final path in possiblePaths) {
    if (File(path).existsSync()) {
      return path;
    }
  }

  return null;
}

void _ensureCoreTablesExist(Database db) {
  final tables = db.select("SELECT name FROM sqlite_master WHERE type='table'");
  final names = tables.map((row) => row['name'] as String).toSet();

  if (!names.contains('songs')) {
    stderr.writeln('ERROR: songs table not found in database.');
  }
  if (!names.contains('setlists')) {
    stderr.writeln('ERROR: setlists table not found in database.');
  }
  if (!names.contains('midi_profiles')) {
    stderr.writeln('ERROR: midi_profiles table not found in database.');
  }
}

class _MigrationReport {
  int totalSongsInJson = 0;
  int totalSongsWithContent = 0;
  int songsInserted = 0;
  int songsSkippedExisting = 0;

  int totalPlaylistsInJson = 0;
  int setlistsInserted = 0;
  int setlistsWithNoValidItems = 0;

  int totalMidiProfilesInJson = 0;
  int midiProfilesWithPcOrCc = 0;
  int midiProfilesInserted = 0;
  int midiProfilesSkippedEmpty = 0;

  int songsWithMidiProfileReference = 0;
  int songsWithResolvedMidiProfile = 0;

  void printToStdout() {
    stdout.writeln('Songs:');
    stdout.writeln('  In JSON           : $totalSongsInJson');
    stdout.writeln('  With content      : $totalSongsWithContent');
    stdout.writeln('  Inserted          : $songsInserted');
    stdout.writeln('  Skipped (existing): $songsSkippedExisting');
    stdout.writeln('');

    stdout.writeln('Setlists:');
    stdout.writeln('  Playlists in JSON : $totalPlaylistsInJson');
    stdout.writeln('  Inserted          : $setlistsInserted');
    stdout.writeln('  With no valid items: $setlistsWithNoValidItems');
    stdout.writeln('');

    stdout.writeln('MIDI Profiles:');
    stdout.writeln('  Profiles in JSON  : $totalMidiProfilesInJson');
    stdout.writeln('  With PC/CC cmds   : $midiProfilesWithPcOrCc');
    stdout.writeln('  Inserted          : $midiProfilesInserted');
    stdout.writeln('  Skipped (empty)   : $midiProfilesSkippedEmpty');
    stdout.writeln('');

    stdout.writeln('Song → MIDI profile links:');
    stdout.writeln(
        '  Songs with reference in JSON : $songsWithMidiProfileReference');
    stdout.writeln(
        '  References resolved to new IDs: $songsWithResolvedMidiProfile');
  }
}

void _processMidiProfiles({
  required Database db,
  required List<Map<String, dynamic>> midiProfilesJson,
  required Map<String, String> midiProfileIdMap,
  required bool whatIf,
  required _MigrationReport report,
}) {
  report.totalMidiProfilesInJson = midiProfilesJson.length;

  for (final profileJson in midiProfilesJson) {
    final oldId = profileJson['id'] as String?;
    final newId = oldId != null ? midiProfileIdMap[oldId] : null;
    final midiMessages = (profileJson['midi'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        <Map<String, dynamic>>[];

    final converted = _convertMidiMessages(midiMessages);
    if (converted == null) {
      report.midiProfilesSkippedEmpty++;
      continue;
    }

    report.midiProfilesWithPcOrCc++;

    final programChangeNumber = converted['programChangeNumber'] as int?;
    final controlChanges =
        converted['controlChanges'] as List<Map<String, dynamic>>;
    final notes = converted['notes'] as String?;

    final name = profileJson['name'] as String? ??
        _generateProfileNameFromCommands(controlChanges, programChangeNumber);

    if (newId == null) {
      // No usable ID, skip but count as empty
      report.midiProfilesSkippedEmpty++;
      continue;
    }

    if (!whatIf) {
      db.execute('''
        INSERT INTO midi_profiles (
          id, name, program_change_number, control_changes,
          timing, notes, created_at, updated_at, is_deleted
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        newId,
        name,
        null, // program_change_number: store PCs in control_changes with controller = -1
        jsonEncode(controlChanges),
        0, // timing (false)
        notes,
        DateTime.now().millisecondsSinceEpoch,
        DateTime.now().millisecondsSinceEpoch,
        0, // is_deleted (false)
      ]);
    }

    report.midiProfilesInserted++;
  }
}

Map<String, dynamic>? _convertMidiMessages(
    List<Map<String, dynamic>> midiMessages) {
  if (midiMessages.isEmpty) return null;

  int? programChangeNumber;
  final List<Map<String, dynamic>> controlChanges = [];

  for (final message in midiMessages) {
    final status = message['status'] as int? ?? 0;
    final data1 = message['data1'] as int? ?? 0;
    final data2 = message['data2'] as int? ?? 0;

    switch (status) {
      case 176: // Control Change (0xB0)
        controlChanges.add({
          'controller': data1,
          'value': data2,
          'label': 'CC$data1:$data2',
        });
        break;
      case 192: // Program Change (0xC0)
        // Represent PC as MidiCC with controller = -1
        programChangeNumber = data1;
        controlChanges.add({
          'controller': -1,
          'value': data1,
          'label': 'PC$data1',
        });
        break;
      default:
        // Ignore other status types, including timing (e.g., 248)
        break;
    }
  }

  if (programChangeNumber == null && controlChanges.isEmpty) {
    return null;
  }

  String? notes;
  final descriptionParts = <String>[];
  if (programChangeNumber != null) {
    descriptionParts.add('PC$programChangeNumber');
  }
  for (final cc in controlChanges) {
    final controller = cc['controller'] as int;
    final value = cc['value'] as int;
    if (controller == -1) {
      descriptionParts.add('PC$value');
    } else {
      descriptionParts.add('CC$controller:$value');
    }
  }

  if (descriptionParts.isNotEmpty) {
    notes =
        'Imported from JustChord library.json: ${descriptionParts.join(', ')}';
  }

  return <String, dynamic>{
    'programChangeNumber': programChangeNumber,
    'controlChanges': controlChanges,
    'notes': notes,
  };
}

String _generateProfileNameFromCommands(
    List<Map<String, dynamic>> controlChanges, int? programChangeNumber) {
  final parts = <String>[];
  if (programChangeNumber != null) {
    parts.add('PC$programChangeNumber');
  }
  for (final cc in controlChanges) {
    final controller = cc['controller'] as int;
    final value = cc['value'] as int;
    if (controller == -1) {
      parts.add('PC$value');
    } else {
      parts.add('CC$controller:$value');
    }
  }
  if (parts.isEmpty) return 'Unnamed Profile';
  return parts.join(', ');
}

void _processSongs({
  required Database db,
  required List<Map<String, dynamic>> songsJson,
  required Map<String, String> songIdMap,
  required Map<String, String> midiProfileIdMap,
  required bool whatIf,
  required _MigrationReport report,
}) {
  report.totalSongsInJson = songsJson.length;

  // Build existing song index by (title, artist) to avoid naive duplicates
  final existingRows = db.select('SELECT id, title, artist FROM songs');
  final existingByTitleArtist = <String, String>{};
  for (final row in existingRows) {
    final title = (row['title'] as String?)?.trim() ?? '';
    final artist = (row['artist'] as String?)?.trim() ?? '';
    if (title.isEmpty) continue;
    final key = '${title.toLowerCase()}::${artist.toLowerCase()}';
    existingByTitleArtist[key] = row['id'] as String;
  }

  for (final songJson in songsJson) {
    final oldId = songJson['id'] as String?;
    final newId = oldId != null ? songIdMap[oldId] : null;

    final title = (songJson['title'] as String? ?? '').trim();
    final artistRaw =
        (songJson['subtitle'] as String? ?? songJson['artist'] as String? ?? '')
            .trim();
    final artist = artistRaw.isEmpty ? 'Unknown Artist' : artistRaw;
    final rawData = songJson['rawData'] as String? ?? '';

    if (title.isEmpty && rawData.isEmpty) {
      continue;
    }

    report.totalSongsWithContent++;

    final key = '${title.toLowerCase()}::${artist.toLowerCase()}';
    if (existingByTitleArtist.containsKey(key)) {
      report.songsSkippedExisting++;
      continue;
    }

    // Extract key chord
    String keyChord = 'C';
    if (songJson['keyChord'] != null) {
      final keyChordMap = songJson['keyChord'] as Map<String, dynamic>;
      keyChord = keyChordMap['key'] as String? ?? 'C';
    }

    // Time signature
    final timeSignature =
        (songJson['timeSignature'] as String? ?? '4/4').replaceAll(r'\/', '/');

    // Tempo -> BPM
    final tempo = songJson['tempo'] as String?;
    int bpm = 120;
    if (tempo != null && tempo.isNotEmpty) {
      try {
        bpm = int.parse(tempo);
      } catch (_) {
        bpm = 120;
      }
    }

    final duration = songJson['duration'] as String?;

    // Convert to ChordPro-ish body (reuse simple strategy from existing scripts)
    final body = _convertToChordProBody(
      rawData: rawData,
      title: title,
      artist: artist,
      key: keyChord,
      timeSignature: timeSignature,
      tempo: tempo,
      duration: duration,
    );

    // Map song-level MIDI profile reference
    String? profileId;
    final midiAppearMessage = songJson['midiAppearMessage'] as String?;
    if (midiAppearMessage != null && midiAppearMessage.isNotEmpty) {
      report.songsWithMidiProfileReference++;
      final mapped = midiProfileIdMap[midiAppearMessage];
      if (mapped != null) {
        profileId = mapped;
        report.songsWithResolvedMidiProfile++;
      }
    }

    if (newId == null) {
      continue;
    }

    final now = DateTime.now().millisecondsSinceEpoch;

    if (!whatIf) {
      db.execute('''
        INSERT INTO songs (
          id, title, artist, body, key, capo, bpm, time_signature,
          tags, audio_file_path, notes, profile_id, duration,
          created_at, updated_at, is_deleted
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        newId,
        title,
        artist,
        body,
        keyChord,
        0, // capo
        bpm,
        timeSignature,
        '[]', // tags: do not import or assign any
        null, // audio_file_path
        oldId != null ? 'Imported from JustChord song $oldId' : null,
        profileId,
        duration,
        now,
        now,
        0, // is_deleted (false)
      ]);
    }

    report.songsInserted++;
  }
}

String _convertToChordProBody({
  required String rawData,
  required String title,
  required String artist,
  required String key,
  required String timeSignature,
  required String? tempo,
  required String? duration,
}) {
  final buffer = StringBuffer();

  if (title.isNotEmpty) {
    buffer.writeln('{title:$title}');
  }
  if (artist.isNotEmpty) {
    buffer.writeln('{artist:$artist}');
  }
  if (key.isNotEmpty) {
    buffer.writeln('{key:$key}');
  }
  if (timeSignature.isNotEmpty) {
    buffer.writeln('{time:$timeSignature}');
  }
  if (tempo != null && tempo.isNotEmpty) {
    buffer.writeln('{tempo:$tempo}');
  }
  if (duration != null && duration.isNotEmpty) {
    buffer.writeln('{duration:$duration}');
  }

  buffer.writeln();

  String converted = rawData;

  converted = converted.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]'),
    (match) {
      final section = match.group(1)!;
      final lower = section.toLowerCase();
      if (lower.contains('verse') ||
          lower.contains('chorus') ||
          lower.contains('bridge') ||
          lower.contains('intro') ||
          lower.contains('outro') ||
          lower.contains('solo') ||
          lower.contains('instrumental') ||
          lower.contains('pre-chorus') ||
          lower.contains('ending')) {
        return '{comment:$section}';
      }
      return '[$section]';
    },
  );

  converted =
      converted.replaceAll(RegExp(r'# Created using SongSheet Pro:.*'), '');

  buffer.write(converted.trim());

  return buffer.toString();
}

void _processPlaylists({
  required Database db,
  required List<Map<String, dynamic>> playlistsJson,
  required Map<String, String> songIdMap,
  required Map<String, String> playlistIdMap,
  required bool whatIf,
  required _MigrationReport report,
}) {
  report.totalPlaylistsInJson = playlistsJson.length;

  for (final playlistJson in playlistsJson) {
    final oldId = playlistJson['id'] as String?;
    final newId = oldId != null ? playlistIdMap[oldId] : null;

    final name = playlistJson['title'] as String? ?? 'Untitled Setlist';
    final arrangement = (playlistJson['arrangement'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        <Map<String, dynamic>>[];

    final setlistItems = <Map<String, dynamic>>[];
    var order = 0;

    for (final item in arrangement) {
      final songOldId = item['id'] as String?;
      if (songOldId == null || songOldId.isEmpty) {
        continue;
      }

      final songNewId = songIdMap[songOldId];
      if (songNewId == null) {
        continue;
      }

      final capo = item['capo'] as int? ?? 0;
      final transpose = item['transpose'] as String?;

      int transposeSteps = 0;
      if (transpose != null && transpose.isNotEmpty) {
        const transposeMap = <String, int>{
          'C#': 1,
          'Db': 1,
          'D': 2,
          'D#': 3,
          'Eb': 3,
          'E': 4,
          'F': 5,
          'F#': 6,
          'Gb': 6,
          'G': 7,
          'G#': 8,
          'Ab': 8,
          'A': 9,
          'A#': 10,
          'Bb': 10,
          'B': 11,
          'C': 0,
        };
        transposeSteps = transposeMap[transpose] ?? 0;
      }

      setlistItems.add(<String, dynamic>{
        'type': 'song',
        'songId': songNewId,
        'order': order,
        'transposeSteps': transposeSteps,
        'capo': capo,
      });
      order++;
    }

    if (setlistItems.isEmpty || newId == null) {
      report.setlistsWithNoValidItems++;
      continue;
    }

    final itemsJson = jsonEncode(setlistItems);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (!whatIf) {
      db.execute('''
        INSERT INTO setlists (
          id, name, items, notes, image_path, setlist_specific_edits_enabled,
          created_at, updated_at, is_deleted
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        newId,
        name,
        itemsJson,
        oldId != null ? 'Imported from JustChord playlist $oldId' : null,
        null, // image_path
        1, // setlist_specific_edits_enabled
        now,
        now,
        0, // is_deleted (false)
      ]);
    }

    report.setlistsInserted++;
  }
}
