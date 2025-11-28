import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/setlist.dart';
import '../providers/setlist_provider.dart';
import '../providers/appearance_provider.dart';
import 'templates/standard_modal_template.dart';

/// Modal-style dialog for adding songs to multiple setlists
///
/// **App Modal Design Standard**:
/// - maxWidth: 480, maxHeight: 650 (constrained dialog)
/// - Gradient: Color(0xFF0468cc) to Color.fromARGB(150, 3, 73, 153)
/// - Border radius: 22, Shadow: blurRadius 20, offset (0, 10)
/// - Text: Primary white, secondary white70, borders white24
/// - Buttons: Rounded borders (999), padding (21, 11), fontSize 14
/// - Spacing: 8px between sections, 16px padding
class AddSongsToSetlistModal extends StatefulWidget {
  final List<Song> songs;

  const AddSongsToSetlistModal({Key? key, required this.songs})
      : super(key: key);

  /// Show the Add Songs to Setlist modal for a single song
  static Future<void> show(BuildContext context, Song song) {
    return StandardModalTemplate.show<void>(
      context: context,
      barrierDismissible: false,
      child: AddSongsToSetlistModal(songs: [song]),
    );
  }

  /// Show the Add Songs to Setlist modal for multiple songs
  static Future<void> showMultiple(BuildContext context, List<Song> songs) {
    return StandardModalTemplate.show<void>(
      context: context,
      barrierDismissible: false,
      child: AddSongsToSetlistModal(songs: songs),
    );
  }

  @override
  State<AddSongsToSetlistModal> createState() => _AddSongsToSetlistModalState();
}

class _AddSongsToSetlistModalState extends State<AddSongsToSetlistModal> {
  final Set<String> _selectedSetlistIds = <String>{};
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Defer setlist loading to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSetlists();
    });
  }

  Future<void> _loadSetlists() async {
    try {
      final setlistProvider = context.read<SetlistProvider>();
      if (setlistProvider.setlists.isEmpty) {
        await setlistProvider.loadSetlists();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return AlertDialog(
        title: const Text('Error'),
        content: Text('Failed to load setlists: $_errorMessage'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return Consumer2<AppearanceProvider, SetlistProvider>(
      builder: (context, appearanceProvider, setlistProvider, child) {
        return StandardModalTemplate.buildModalContainer(
          context: context,
          appearanceProvider: appearanceProvider,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StandardModalTemplate.buildHeader(
                context: context,
                title: 'Add to Setlist',
                onCancel: () => Navigator.of(context).pop(),
                onOk: _selectedSetlistIds.isEmpty
                    ? () {}
                    : () {
                        // Defer the entire operation to avoid setState during build
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _addToSetlists(context);
                        });
                      },
                okEnabled: _selectedSetlistIds.isNotEmpty,
                okLabel: 'Add',
              ),
              StandardModalTemplate.buildContent(
                children: [
                  _buildSongInfo(),
                  const SizedBox(height: 12),
                  _buildSetlistList(setlistProvider),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongInfo() {
    final isMultiple = widget.songs.length > 1;

    return Container(
      padding: const EdgeInsets.all(9), // Reduced by 25% from 12
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Row(
        children: [
          Icon(
            isMultiple ? Icons.library_music : Icons.music_note,
            color: Colors.white70,
            size: 15, // Reduced by 25% from 20
          ),
          const SizedBox(width: 9), // Reduced by 25% from 12
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMultiple
                      ? '${widget.songs.length} songs selected'
                      : widget.songs.first.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5, // Reduced by 25% from 14
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isMultiple && widget.songs.first.artist.isNotEmpty) ...[
                  const SizedBox(height: 1.5), // Reduced by 25% from 2
                  Text(
                    widget.songs.first.artist,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9, // Reduced by 25% from 12
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ] else if (isMultiple) ...[
                  const SizedBox(height: 1.5), // Reduced by 25% from 2
                  Text(
                    'Add to setlists',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9, // Reduced by 25% from 12
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Key badge (only for single song)
          if (!isMultiple)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 3), // Reduced by 25% from 8,4
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(6), // Reduced by 25% from 8
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: Text(
                widget.songs.first.key,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9, // Reduced by 25% from 12
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSetlistList(SetlistProvider setlistProvider) {
    if (setlistProvider.setlists.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.playlist_play,
              size: 48,
              color: Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            const Text(
              'No setlists found',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Create a setlist first to add songs',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'SELECT SETLISTS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 9, // Reduced by 25% from 12
                ),
              ),
            ),
            Text(
              '${_selectedSetlistIds.length} selected',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 8.25, // Reduced by 25% from 11
              ),
            ),
          ],
        ),
        const SizedBox(height: 6), // Reduced by 25% from 8
        // Filter out setlists that already contain ALL the songs
        ...setlistProvider.setlists.where((setlist) {
          final allSongsInSetlist = widget.songs.every((song) => setlist.items
              .whereType<SetlistSongItem>()
              .any((item) => item.songId == song.id));
          return !allSongsInSetlist; // Only show setlists that don't have all songs
        }).map((setlist) {
          final isSelected = _selectedSetlistIds.contains(setlist.id);
          return _buildSetlistTile(setlist, isSelected);
        }).toList(),
      ],
    );
  }

  Widget _buildSetlistTile(Setlist setlist, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6), // Reduced by 25% from 8
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withAlpha(20)
            : Colors.black.withAlpha(45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.white.withAlpha(50) : Colors.white12,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 9, vertical: 3), // Reduced by 25% from 12,4
        leading: Checkbox(
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _selectedSetlistIds.add(setlist.id);
              } else {
                _selectedSetlistIds.remove(setlist.id);
              }
            });
          },
          activeColor: Colors.white,
          checkColor: const Color(0xFF0468cc),
          fillColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.disabled)) {
              return Colors.white24;
            }
            if (states.contains(MaterialState.selected)) {
              return Colors.white;
            }
            return Colors.white.withAlpha(50);
          }),
        ),
        title: Text(
          setlist.name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 9.75, // Reduced by 25% from 13
          ),
        ),
        subtitle: Text(
          '${setlist.items.whereType<SetlistSongItem>().length} songs',
          style: const TextStyle(
              color: Colors.white70, fontSize: 8.25), // Reduced by 25% from 11
        ),
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedSetlistIds.remove(setlist.id);
            } else {
              _selectedSetlistIds.add(setlist.id);
            }
          });
        },
      ),
    );
  }

  Future<void> _addToSetlists(BuildContext context) async {
    if (_selectedSetlistIds.isEmpty) return;

    try {
      final setlistProvider = context.read<SetlistProvider>();
      int totalAddedCount = 0;

      for (final setlistId in _selectedSetlistIds) {
        final setlist = setlistProvider.setlists
            .where((s) => s.id == setlistId)
            .firstOrNull;

        if (setlist != null) {
          final newItems = List<SetlistItem>.from(setlist.items);
          int addedToThisSetlist = 0;

          // Add each song that's not already in the setlist
          for (final song in widget.songs) {
            final songAlreadyExists = setlist.items
                .whereType<SetlistSongItem>()
                .any((item) => item.songId == song.id);

            if (!songAlreadyExists) {
              newItems.add(SetlistSongItem(
                id: Uuid().v4(),
                songId: song.id,
                order: newItems.length,
                transposeSteps: 0, // Default transpose for new setlist items
                capo: song.capo, // Copy capo from base song
              ));
              addedToThisSetlist++;
            }
          }

          // Only update if we added songs
          if (addedToThisSetlist > 0) {
            final updatedSetlist = setlist.copyWith(
              items: newItems,
              updatedAt: DateTime.now(),
            );

            await setlistProvider.updateSetlist(updatedSetlist);
            totalAddedCount += addedToThisSetlist;
          }
        }
      }

      if (context.mounted) {
        Navigator.of(context).pop();

        final isMultiple = widget.songs.length > 1;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              totalAddedCount > 0
                  ? isMultiple
                      ? 'Added $totalAddedCount song${totalAddedCount == 1 ? '' : 's'} to ${_selectedSetlistIds.length} setlist${_selectedSetlistIds.length == 1 ? '' : 's'}${totalAddedCount < widget.songs.length ? ' (duplicates skipped)' : ''}'
                      : 'Added "${widget.songs.first.title}" to ${_selectedSetlistIds.length} setlist${_selectedSetlistIds.length == 1 ? '' : 's'}'
                  : 'All songs were already in selected setlists',
            ),
            backgroundColor: totalAddedCount > 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add songs to setlists: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
