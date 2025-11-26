import 'lib/services/song_metadata_service.dart';

void main() async {
  print('Testing SongMetadataService...');

  final service = SongMetadataService();
  final result = await service.fetchMetadata(
    title: "Wonderwall",
    artist: "Oasis",
  );

  print('Result: ${result.success}');
  print('Tempo: ${result.tempoBpm}');
  print('Key: ${result.key}');
  print('Time Signature: ${result.timeSignature}');
  print('Duration: ${result.durationMs}');
  print('Error: ${result.error}');
}
