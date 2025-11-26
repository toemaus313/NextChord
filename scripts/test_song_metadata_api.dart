import '../lib/services/song_metadata_service.dart';

void main() async {
  print('🎵 Testing Song Metadata API');
  print('================================');

  final service = SongMetadataService();

  // Test cases
  final testCases = [
    {'title': 'Wonderwall', 'artist': 'Oasis'},
    {'title': 'Bohemian Rhapsody', 'artist': 'Queen'},
    {'title': 'Stairway to Heaven', 'artist': 'Led Zeppelin'},
    {'title': 'Hotel California', 'artist': 'Eagles'},
  ];

  for (int i = 0; i < testCases.length; i++) {
    final testCase = testCases[i];
    final title = testCase['title']!;
    final artist = testCase['artist']!;

    print('\n${i + 1}. Testing: "$title" by $artist');
    print('----------------------------------------');

    try {
      final result = await service.fetchMetadata(
        title: title,
        artist: artist,
      );

      print('✅ Success: ${result.success}');
      print('🎵 Tempo: ${result.tempoBpm ?? 'N/A'} BPM');
      print('🎹 Key: ${result.key ?? 'N/A'}');
      print('⏱️  Time Signature: ${result.timeSignature ?? 'N/A'}');
      print(
          '⏳ Duration: ${result.durationMs != null ? '${(result.durationMs! / 1000 / 60).floor()}:${(result.durationMs! / 1000 % 60).floor().toString().padLeft(2, '0')}' : 'N/A'}');

      if (result.error != null) {
        print('❌ Error: ${result.error}');
      }
    } catch (e) {
      print('❌ Exception: $e');
    }

    // Small delay between requests to be respectful to APIs
    if (i < testCases.length - 1) {
      print('⏳ Waiting 2 seconds before next request...');
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  print('\n🏁 Testing complete!');
}
