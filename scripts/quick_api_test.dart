import 'package:flutter/material.dart';
import '../lib/services/song_metadata_service.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API Test',
      home: const ApiTestScreen(),
    );
  }
}

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  final SongMetadataService _service = SongMetadataService();
  String _result = 'Press button to test API';
  bool _isLoading = false;

  Future<void> _testApi() async {
    setState(() {
      _isLoading = true;
      _result = 'Testing...';
    });

    try {
      final apiResult = await _service.fetchMetadata(
        title: 'Wonderwall',
        artist: 'Oasis',
      );

      setState(() {
        if (apiResult.success) {
          _result = '''
✅ SUCCESS!
Tempo: ${apiResult.tempoBpm ?? 'N/A'} BPM
Key: ${apiResult.key ?? 'N/A'}
Time Signature: ${apiResult.timeSignature ?? 'N/A'}
Duration: ${apiResult.durationMs != null ? '${(apiResult.durationMs! / 1000 / 60).floor()}:${(apiResult.durationMs! / 1000 % 60).floor().toString().padLeft(2, '0')}' : 'N/A'}
          ''';
        } else {
          _result = '❌ Error: ${apiResult.error ?? 'Unknown error'}';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _result = '❌ Exception: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Song Metadata API Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testApi,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test SongBPM API'),
            ),
            const SizedBox(height: 20),
            Text(_result),
          ],
        ),
      ),
    );
  }
}
