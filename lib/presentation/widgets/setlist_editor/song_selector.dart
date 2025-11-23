import 'package:flutter/material.dart';
import '../../../domain/entities/setlist.dart';
import '../../../domain/entities/song.dart';

/// Song selection and management component
class SongSelector extends StatelessWidget {
  final List<SetlistSongItem> songs;
  final List<Song> availableSongs;
  final VoidCallback onAddSongs;
  final Function(int) onRemoveSong;
  final Function(int, int) onMoveSong;
  final Function(int, int) onTransposeSong;
  final Function(int, int) onCapoSong;

  const SongSelector({
    super.key,
    required this.songs,
    required this.availableSongs,
    required this.onAddSongs,
    required this.onRemoveSong,
    required this.onMoveSong,
    required this.onTransposeSong,
    required this.onCapoSong,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Songs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: onAddSongs,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  'Add Songs',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.white.withAlpha(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (songs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: const Column(
                children: [
                  Icon(
                    Icons.music_note,
                    size: 48,
                    color: Colors.white38,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No songs added yet',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Click "Add Songs" to get started',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: songs.length,
              onReorder: onMoveSong,
              itemBuilder: (context, index) {
                final song = songs[index];
                return _SongItem(
                  key: ValueKey(song.songId),
                  song: song,
                  availableSongs: availableSongs,
                  index: index,
                  onRemove: () => onRemoveSong(index),
                  onTranspose: (semitones) => onTransposeSong(index, semitones),
                  onCapo: (fret) => onCapoSong(index, fret),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SongItem extends StatelessWidget {
  final SetlistSongItem song;
  final List<Song> availableSongs;
  final int index;
  final VoidCallback onRemove;
  final Function(int) onTranspose;
  final Function(int) onCapo;

  const _SongItem({
    super.key,
    required this.song,
    required this.availableSongs,
    required this.index,
    required this.onRemove,
    required this.onTranspose,
    required this.onCapo,
  });

  Song _getSongById(String songId) {
    try {
      return availableSongs.firstWhere((song) => song.id == songId);
    } catch (e) {
      return Song(
        id: '',
        title: 'Unknown Song',
        artist: 'Unknown Artist',
        body: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.drag_handle,
                color: Colors.white38,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getSongById(song.songId).title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _getSongById(song.songId).artist,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          if (song.transposeSteps != 0 || song.capo != 0)
            Container(
              margin: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (song.transposeSteps != 0) ...[
                    _TransposeControl(
                      value: song.transposeSteps,
                      onChanged: onTranspose,
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (song.capo != 0) ...[
                    _CapoControl(
                      value: song.capo,
                      onChanged: onCapo,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TransposeControl extends StatelessWidget {
  final int value;
  final Function(int) onChanged;

  const _TransposeControl({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Transpose:',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => onChanged(value - 1),
                icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '${value > 0 ? '+' : ''}$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onChanged(value + 1),
                icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CapoControl extends StatelessWidget {
  final int value;
  final Function(int) onChanged;

  const _CapoControl({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Capo:',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(10),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withAlpha(20)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => onChanged((value - 1).clamp(0, 12)),
                icon: const Icon(Icons.remove, size: 16, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  value.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => onChanged((value + 1).clamp(0, 12)),
                icon: const Icon(Icons.add, size: 16, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
