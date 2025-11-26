import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('🎵 Testing SongBPM API Directly');
  print('=================================');

  const apiKey = '0b0d119c98912195fa14e1153cbd79e6';
  const baseUrl = 'https://api.getsongbpm.com/v1';

  final testCases = [
    {'title': 'Wonderwall', 'artist': 'Oasis'},
    {'title': 'Bohemian Rhapsody', 'artist': 'Queen'},
  ];

  for (int i = 0; i < testCases.length; i++) {
    final testCase = testCases[i];
    final title = testCase['title']!;
    final artist = testCase['artist']!;

    print('\n${i + 1}. Testing: "$title" by $artist');
    print('----------------------------------------');

    try {
      final url = Uri.parse(
          '$baseUrl/search/?api_key=$apiKey&type=song&artist=$artist&title=$title');

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'NextChord/1.0.0 ( tommy@antonovich.us )',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ API Response Status: ${response.statusCode}');

        if (data['status'] == 'success' &&
            data['search'] != null &&
            data['search'].isNotEmpty) {
          final song = data['search'][0];
          print('🎵 Tempo: ${song['tempo'] ?? 'N/A'} BPM');
          print('🎹 Key: ${song['key'] ?? 'N/A'}');
          print('⏱️  Time Signature: ${song['time_signature'] ?? 'N/A'}');
          print('🎼 Title: ${song['title'] ?? 'N/A'}');
          print('🎤 Artist: ${song['artist'] ?? 'N/A'}');
        } else {
          print('❌ No results found');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        print('Response: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception: $e');
    }

    // Small delay between requests
    if (i < testCases.length - 1) {
      print('⏳ Waiting 2 seconds before next request...');
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  print('\n🏁 Testing complete!');
}
