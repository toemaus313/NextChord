import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/setlist.dart';
import '../providers/setlist_provider.dart';
import '../widgets/setlist_editor_dialog.dart';

/// Screen that displays all setlists
class SetlistsScreen extends StatefulWidget {
  const SetlistsScreen({Key? key}) : super(key: key);

  @override
  State<SetlistsScreen> createState() => _SetlistsScreenState();
}

class _SetlistsScreenState extends State<SetlistsScreen> {
  @override
  void initState() {
    super.initState();
    // Load setlists when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SetlistProvider>().loadSetlists();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createNewSetlist(),
            tooltip: 'Create Setlist',
          ),
        ],
      ),
      body: Consumer<SetlistProvider>(
        builder: (context, provider, child) {
          // Loading state
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (provider.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage ?? 'Unknown error',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadSetlists(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Empty state
          if (provider.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.playlist_play, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No setlists yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('Tap + to create your first setlist'),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _createNewSetlist(),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Setlist'),
                  ),
                ],
              ),
            );
          }

          // Setlists grid
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: provider.setlists.length,
            itemBuilder: (context, index) {
              final setlist = provider.setlists[index];
              return _buildSetlistCard(setlist);
            },
          );
        },
      ),
    );
  }

  Widget _buildSetlistCard(Setlist setlist) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSetlist(setlist),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image (200x200)
            AspectRatio(
              aspectRatio: 1.0,
              child: setlist.imagePath != null
                  ? _buildSetlistImage(setlist.imagePath!)
                  : _buildPlaceholderImage(),
            ),
            // Setlist info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      setlist.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${setlist.items.length} songs',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(
          Icons.playlist_play,
          size: 64,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSetlistImage(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    }

    final file = File(path);
    if (!file.existsSync()) {
      return _buildPlaceholderImage();
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
    );
  }

  void _createNewSetlist() async {
    final result = await SetlistEditorDialog.show(context);
    if (result == true && mounted) {
      context.read<SetlistProvider>().loadSetlists();
    }
  }

  void _openSetlist(Setlist setlist) async {
    final result = await SetlistEditorDialog.show(
      context,
      setlist: setlist,
    );
    if (result == true && mounted) {
      context.read<SetlistProvider>().loadSetlists();
    }
  }
}
