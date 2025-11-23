import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/setlist.dart';
import '../../domain/entities/song.dart';
import '../providers/setlist_provider.dart';
import '../providers/song_provider.dart';
import '../../services/setlist/setlist_service.dart';
import 'setlist_editor/image_picker.dart';

/// Gradient-styled dialog for creating or editing a setlist
class SetlistEditorDialog extends StatefulWidget {
  final Setlist? setlist;

  const SetlistEditorDialog({super.key, this.setlist});

  static Future<bool?> show(
    BuildContext context, {
    Setlist? setlist,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: SetlistEditorDialog(setlist: setlist),
      ),
    );
  }

  /// Show dialog to add songs to a setlist
  static Future<List<String>?> showAddSongs(
      BuildContext context, List<SetlistSongItem> currentItems) async {
    final songProvider = context.read<SongProvider>();
    final searchController = TextEditingController();

    // Reset selection mode and load songs if needed
    songProvider.resetSelectionMode();
    // Enable selection mode by default
    songProvider.toggleSelectionMode();
    if (songProvider.songs.isEmpty && !songProvider.isLoading) {
      await songProvider.loadSongs();
    }

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0468cc),
                Color.fromARGB(150, 3, 73, 153),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cancel button in upper left
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withAlpha(20),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cancel'),
                    ),
                    // Centered title
                    const Expanded(
                      child: Text(
                        'Add Songs',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Save button in upper right
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(
                        songProvider.selectedSongIds.toList(),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withAlpha(20),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
              // Search bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search songs...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                  onChanged: (query) {
                    songProvider.searchSongs(query);
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Song list
              Expanded(
                child: Consumer<SongProvider>(
                  builder: (context, songProvider, _) {
                    if (songProvider.isLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      );
                    }

                    if (songProvider.songs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No songs found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: songProvider.songs.length,
                      itemBuilder: (context, index) {
                        final song = songProvider.songs[index];
                        final isSelected =
                            songProvider.selectedSongIds.contains(song.id);
                        final alreadyAdded =
                            currentItems.any((item) => item.songId == song.id);

                        // Skip songs that are already added
                        if (alreadyAdded) {
                          return const SizedBox.shrink();
                        }

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (value) {
                            if (value == true) {
                              songProvider.selectSong(song);
                            } else {
                              songProvider.deselectSong(song);
                            }
                          },
                          title: Text(
                            song.title,
                            style: const TextStyle(
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            song.artist,
                            style: const TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                          activeColor: Colors.white,
                          checkColor: const Color(0xFF0468cc),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Clean up
    songProvider.resetSelectionMode();
    searchController.dispose();

    return result;
  }

  @override
  State<SetlistEditorDialog> createState() => _SetlistEditorDialogState();
}

class _SetlistEditorDialogState extends State<SetlistEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  late final SetlistService _setlistService;

  List<SetlistSongItem> _songs = [];
  Set<String> _selectedSongs = {}; // Track selected songs for bulk deletion
  bool _isSelectionMode = false; // Track if selection mode is active
  String? _imagePath;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _imageLoading = false;

  @override
  void initState() {
    super.initState();
    _setlistService = SetlistService(
      Provider.of<SetlistProvider>(context, listen: false).repository,
    );
    _initializeData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (widget.setlist != null) {
      setState(() {
        _nameController.text = widget.setlist!.name;
        // Extract only song items from the setlist items
        _songs = widget.setlist!.items.whereType<SetlistSongItem>().toList();
        _imagePath = widget.setlist!.imagePath;
      });
      await _loadImageBytes();
    }
  }

  Future<void> _loadImageBytes() async {
    if (_imagePath != null) {
      setState(() => _imageLoading = true);
      try {
        final bytes = await _setlistService.loadImageBytes(_imagePath);
        if (mounted) {
          setState(() => _imageBytes = bytes);
        }
      } catch (e) {
      } finally {
        if (mounted) {
          setState(() => _imageLoading = false);
        }
      }
    }
  }

  Future<void> _pickImage() async {
    setState(() => _imageLoading = true);
    try {
      final sourcePath = await _setlistService.pickImage();
      if (sourcePath != null) {
        final savedPath =
            await _setlistService.saveImageToAppDirectory(sourcePath);
        if (savedPath != null && mounted) {
          setState(() {
            _imagePath = savedPath;
          });
          await _loadImageBytes();
        }
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    } finally {
      if (mounted) {
        setState(() => _imageLoading = false);
      }
    }
  }

  Future<void> _removeImage() async {
    if (_imagePath != null) {
      await _setlistService.deleteImageFile(_imagePath);
      setState(() {
        _imagePath = null;
        _imageBytes = null;
      });
    }
  }

  Future<void> _addSongs() async {
    final songProvider = Provider.of<SongProvider>(context, listen: false);
    if (songProvider.songs.isEmpty && !songProvider.isLoading) {
      await songProvider.loadSongs();
    }

    final result = await SetlistEditorDialog.showAddSongs(context, _songs);
    if (result != null && result.isNotEmpty) {
      final songProvider = Provider.of<SongProvider>(context, listen: false);
      final availableSongs = songProvider.songs;
      final newItems =
          _setlistService.createSetlistSongItems(result, availableSongs);

      setState(() {
        _songs.addAll(newItems);
      });
    }
  }

  void _removeSong(int index) {
    setState(() {
      _songs.removeAt(index);
    });
  }

  void _moveSong(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    setState(() {
      final item = _songs.removeAt(oldIndex);
      _songs.insert(newIndex, item);
    });
  }

  void _deleteSelectedSongs() {
    setState(() {
      _songs.removeWhere((song) => _selectedSongs.contains(song.id));
      _selectedSongs.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _saveSetlist() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate setlist data
    final validationError = _setlistService.validateSetlist(
      name: _nameController.text,
      songs: _songs,
    );

    if (validationError != null) {
      _showError(validationError);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _setlistService.saveSetlist(
        name: _nameController.text.trim(),
        description:
            '', // Empty description for now until database schema is updated
        songs: _songs,
        imagePath: _imagePath,
        id: widget.setlist?.id,
        createdAt: widget.setlist?.createdAt,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      _showError('Failed to save setlist: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0468cc),
              Color.fromARGB(150, 3, 73, 153),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Cancel button in upper left
                  ElevatedButton(
                    onPressed: _isLoading ? null : _cancel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(20),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cancel'),
                  ),
                  // Centered title
                  Expanded(
                    child: Text(
                      widget.setlist == null
                          ? 'Create Setlist'
                          : 'Edit Setlist',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Save button in upper right
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveSetlist,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(20),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image picker at top
                      SetlistImagePicker(
                        imagePath: _imagePath,
                        imageBytes: _imageBytes,
                        isLoading: _imageLoading,
                        onPickImage: _pickImage,
                        onRemoveImage: _removeImage,
                      ),
                      const SizedBox(height: 16),
                      // Name field underneath image
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Setlist Name',
                          labelStyle: TextStyle(color: Colors.white70),
                          hintText: 'Enter setlist name',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: OutlineInputBorder(),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a setlist name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Custom songs list matching sidebar implementation
                      _buildSongsList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongsList() {
    return Consumer<SongProvider>(
      builder: (context, songProvider, child) {
        final songsMap = {
          for (final song in songProvider.songs) song.id: song,
        };

        if (_songs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Center(
                  child: Text(
                    'No songs in this setlist',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 16),
                // Add Songs button for empty setlist
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _addSongs,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Songs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(20),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Selection controls
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  // Selection mode toggle
                  ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isSelectionMode = !_isSelectionMode;
                              _selectedSongs.clear();
                            });
                          },
                    icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist,
                        size: 16),
                    label: Text(
                        _isSelectionMode ? 'Cancel Selection' : 'Select Songs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSelectionMode
                          ? Colors.red.withAlpha(20)
                          : Colors.white.withAlpha(20),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bulk delete button
                  if (_isSelectionMode && _selectedSongs.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _deleteSelectedSongs,
                      icon: const Icon(Icons.delete, size: 16),
                      label: Text('Delete (${_selectedSongs.length})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withAlpha(40),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  const Spacer(),
                  // Add Songs button
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _addSongs,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Songs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(20),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // Songs list
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                itemCount: _songs.length,
                onReorder: _moveSong,
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final item = _songs[index];
                  final song = songsMap[item.songId];
                  return _buildSongItem(item, song, index);
                },
                // Custom drag highlight color
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (BuildContext context, Widget? child) {
                      return Material(
                        color: const Color(0xFF0468cc).withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        elevation: 4,
                        child: child,
                      );
                    },
                    child: child,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSongItem(SetlistSongItem item, Song? song, int index) {
    final title = song?.title ?? 'Unknown song';
    final artist = song?.artist ?? '';

    // Calculate effective key and capo
    String displayKey = song?.key ?? '';
    int capo = item.capo;

    if (song != null && item.transposeSteps != 0) {
      // Apply transpose to key
      displayKey = _transposeKey(displayKey, item.transposeSteps);
    }

    return Container(
      key: ValueKey('song_${item.songId}_$index'),
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          // Selection checkbox or drag handle
          if (_isSelectionMode)
            Checkbox(
              value: _selectedSongs.contains(item.id),
              onChanged: _isLoading
                  ? null
                  : (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedSongs.add(item.id);
                        } else {
                          _selectedSongs.remove(item.id);
                        }
                      });
                    },
              activeColor: Colors.white,
              checkColor: const Color(0xFF0468cc),
            )
          else
            ReorderableDragStartListener(
              index: index,
              child: const Icon(
                Icons.drag_indicator,
                color: Colors.white54,
                size: 16,
              ),
            ),
          const SizedBox(width: 8),
          // Song info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (artist.isNotEmpty)
                  Text(
                    artist,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Key and capo info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                displayKey,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (capo > 0)
                Text(
                  'Capo $capo',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
          // Delete button (only in non-selection mode)
          if (!_isSelectionMode)
            IconButton(
              onPressed: _isLoading ? null : () => _removeSong(index),
              icon: const Icon(
                Icons.remove_circle,
                size: 18,
                color: Colors.red,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  String _transposeKey(String key, int semitones) {
    // Simple key transposition logic (can be expanded)
    final keys = [
      'C',
      'C#',
      'D',
      'D#',
      'E',
      'F',
      'F#',
      'G',
      'G#',
      'A',
      'A#',
      'B'
    ];
    if (key.isEmpty) return key;

    final cleanKey = key.replaceAll(RegExp(r'm|maj|min|dim|aug'), '');
    final suffix = key.replaceAll(cleanKey, '');

    int index = keys.indexOf(cleanKey);
    if (index == -1) return key;

    int newIndex = (index + semitones) % 12;
    if (newIndex < 0) newIndex += 12;

    return keys[newIndex] + suffix;
  }
}
