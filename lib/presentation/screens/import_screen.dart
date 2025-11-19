import 'package:flutter/material.dart';
import '../../core/utils/justchords_importer.dart';
import '../../data/repositories/song_repository.dart';
import '../../data/database/app_database.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _isImporting = false;
  String _statusMessage = '';
  int _importedCount = 0;

  Future<void> _importSongs() async {
    setState(() {
      _isImporting = true;
      _statusMessage = 'Reading library.json...';
      _importedCount = 0;
    });

    try {
      // Import 5 random songs
      setState(() {
        _statusMessage = 'Parsing songs...';
      });

      final songs = await JustchordsImporter.importFromFile(
        'examples/library.json',
        count: 5,
      );

      setState(() {
        _statusMessage = 'Importing ${songs.length} songs to database...';
      });

      // Save to database
      final db = AppDatabase();
      final repository = SongRepository(db);

      for (final song in songs) {
        await repository.insertSong(song);
        setState(() {
          _importedCount++;
          _statusMessage = 'Imported $_importedCount of ${songs.length}...';
        });
      }

      await db.close();

      setState(() {
        _isImporting = false;
        _statusMessage = '✅ Successfully imported ${songs.length} songs!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported ${songs.length} songs from Justchords'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
        _statusMessage = '❌ Error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Justchords'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Songs',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'This will import 5 random songs from the Justchords library.json file.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Songs will be tagged with "imported" and "justchords".',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_statusMessage.isNotEmpty)
              Card(
                color: _statusMessage.startsWith('❌')
                    ? Colors.red.shade50
                    : _statusMessage.startsWith('✅')
                        ? Colors.green.shade50
                        : Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _statusMessage.startsWith('❌')
                          ? Colors.red.shade900
                          : _statusMessage.startsWith('✅')
                              ? Colors.green.shade900
                              : Colors.blue.shade900,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isImporting ? null : _importSongs,
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download),
              label: Text(_isImporting ? 'Importing...' : 'Import 5 Random Songs'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'About the Import',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Source: examples/library.json (604 songs)\n'
              '• Format: Converted to ChordPro\n'
              '• Tags: ["imported", "justchords"]\n'
              '• Metadata: Title, artist, key, tempo, time signature preserved',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
