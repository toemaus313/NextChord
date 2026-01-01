import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/setlist.dart';
import '../../domain/entities/song.dart';
import '../providers/setlist_provider.dart';
import '../providers/song_provider.dart';
import '../providers/appearance_provider.dart';
import '../../services/setlist/setlist_service.dart';
import 'templates/standard_modal_template.dart';
import 'setlist_editor/image_picker.dart';
import 'add_divider_modal.dart';
import 'standard_wide_button.dart';

/// Gradient-styled dialog for creating or editing a setlist
class SetlistEditorDialog extends StatefulWidget {
  final Setlist? setlist;

  const SetlistEditorDialog({Key? key, this.setlist}) : super(key: key);

  static Future<bool?> show(
    BuildContext context, {
    Setlist? setlist,
  }) {
    return StandardModalTemplate.show<bool>(
      context: context,
      barrierDismissible: false,
      child: SetlistEditorDialog(setlist: setlist),
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
      builder: (context) {
        return Consumer<AppearanceProvider>(
          builder: (context, appearanceProvider, _) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: StandardModalTemplate.buildModalContainer(
                context: context,
                appearanceProvider: appearanceProvider,
                maxHeight: 800,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Standard header with Cancel / Save
                    StandardModalTemplate.buildHeader(
                      context: context,
                      title: 'Add Songs',
                      onCancel: () => Navigator.of(context).pop(),
                      onOk: () => Navigator.of(context).pop(
                        songProvider.selectedSongIds.toList(),
                      ),
                    ),
                    // Content area
                    StandardModalTemplate.buildContent(
                      children: [
                        // Search bar
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search songs...',
                              hintStyle: const TextStyle(color: Colors.white38),
                              prefixIcon: const Icon(Icons.search,
                                  color: Colors.white38),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.white24),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.white24),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Colors.white),
                              ),
                            ),
                            onChanged: (query) {
                              songProvider.searchSongs(query);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Song list (fixed height inside scrollable content)
                        SizedBox(
                          height: 360,
                          child: Consumer<SongProvider>(
                            builder: (context, songProvider, _) {
                              if (songProvider.isLoading) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
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
                                  final isSelected = songProvider
                                      .selectedSongIds
                                      .contains(song.id);
                                  final alreadyAdded = currentItems
                                      .any((item) => item.songId == song.id);

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
                  ],
                ),
              ),
            );
          },
        );
      },
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

  List<SetlistItem> _items = [];
  Set<String> _selectedItems = {}; // Track selected items for bulk deletion
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
        // Load all setlist items (songs and dividers)
        _items = widget.setlist!.items;
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
      final sourcePath = await _setlistService.pickImage(context);
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

    final result = await SetlistEditorDialog.showAddSongs(context, _items.whereType<SetlistSongItem>().toList());
    if (result != null && result.isNotEmpty) {
      final songProvider = Provider.of<SongProvider>(context, listen: false);
      final availableSongs = songProvider.songs;
      final newItems =
          _setlistService.createSetlistSongItems(result, availableSongs);

      setState(() {
        _items.addAll(newItems);
      });
    }
  }

  void _showAddDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'Add to Setlist',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.horizontal_rule),
                title: const Text('Add Divider'),
                onTap: () {
                  Navigator.pop(context);
                  _addDivider();
                },
              ),
              ListTile(
                leading: const Icon(Icons.music_note),
                title: const Text('Add Songs To Setlist'),
                onTap: () {
                  Navigator.pop(context);
                  _addSongs();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addDivider() async {
    final result = await AddDividerModal.show(context);
    
    if (result != null) {
      // Create a divider item and add it to the original setlist's items
      if (widget.setlist != null) {
        final newDivider = SetlistDividerItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          order: widget.setlist!.items.length,
          label: result['label']!,
          color: result['color']!,
        );
        
        // Update the original setlist with the divider
        final updatedSetlist = widget.setlist!.copyWith(
          items: [...widget.setlist!.items, newDivider],
          updatedAt: DateTime.now(),
        );
        
        // Update the setlist in the provider
        final setlistProvider = Provider.of<SetlistProvider>(context, listen: false);
        await setlistProvider.updateSetlist(updatedSetlist);
      }
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _moveItem(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
    });
  }

  void _deleteSelectedItems() {
    setState(() {
      _items.removeWhere((item) => _selectedItems.contains(item.id));
      _selectedItems.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _saveSetlist() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate setlist data
    final validationError = _setlistService.validateSetlist(
      name: _nameController.text,
      items: _items,
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
        items: _items,
        imagePath: _imagePath,
        id: widget.setlist?.id,
        createdAt: widget.setlist?.createdAt,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
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
    return Consumer<AppearanceProvider>(
      builder: (context, appearanceProvider, _) {
        return StandardModalTemplate.buildModalContainer(
          context: context,
          appearanceProvider: appearanceProvider,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StandardModalTemplate.buildHeader(
                context: context,
                title:
                    widget.setlist == null ? 'Create Setlist' : 'Edit Setlist',
                onCancel: _isLoading ? () {} : _cancel,
                onOk: _isLoading ? () {} : _saveSetlist,
                okEnabled: !_isLoading,
              ),
              StandardModalTemplate.buildContent(
                children: [
                  // Wrap fields in a Form so _formKey.currentState is non-null
                  Form(
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
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSongsList() {
    return Consumer<SongProvider>(
      builder: (context, songProvider, child) {
        final songsMap = {
          for (final song in songProvider.songs) song.id: song,
        };

        if (_items.isEmpty) {
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
                // Add button for empty setlist (shows drawer)
                ElevatedButton(
                  onPressed: _isLoading ? null : _showAddDrawer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withAlpha(20),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(36, 36),
                  ),
                  child: const Icon(Icons.add, size: 20),
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
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isSelectionMode = !_isSelectionMode;
                              _selectedItems.clear();
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSelectionMode
                          ? Colors.red.withAlpha(20)
                          : Colors.white.withAlpha(20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: const Size(36, 36),
                    ),
                    child: Icon(
                        _isSelectionMode ? Icons.close : Icons.checklist,
                        size: 20),
                  ),
                  const SizedBox(width: 8),
                  // Bulk delete button
                  if (_isSelectionMode && _selectedItems.isNotEmpty)
                    ElevatedButton(
                      onPressed: _isLoading ? null : _deleteSelectedItems,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withAlpha(40),
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        minimumSize: const Size(36, 36),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delete, size: 16),
                          const SizedBox(width: 4),
                          Text('(${_selectedItems.length})'),
                        ],
                      ),
                    ),
                  const Spacer(),
                  // Add button (shows drawer)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _showAddDrawer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha(20),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: const Size(36, 36),
                    ),
                    child: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            ),
            // Items list
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
                itemCount: _items.length,
                onReorder: _moveItem,
                buildDefaultDragHandles: false,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  if (item is SetlistSongItem) {
                    final song = songsMap[item.songId];
                    return _buildSongItem(item, song, index);
                  } else if (item is SetlistDividerItem) {
                    return _buildDividerItem(item, index, songsMap);
                  }
                  return const SizedBox.shrink();
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
            // Static Total divider (always shown)
            _buildTotalDivider(widget.setlist!, songsMap),
            _buildAddButton(context),
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
              value: _selectedItems.contains(item.id),
              onChanged: _isLoading
                  ? null
                  : (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedItems.add(item.id);
                        } else {
                          _selectedItems.remove(item.id);
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
              onPressed: _isLoading ? null : () => _removeItem(index),
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

  Widget _buildDividerItem(SetlistDividerItem item, int index, Map<String, Song> songsMap) {
    final dividerColor = _parseColor(item.color);

    // Calculate duration for this divider
    final duration = _calculateDividerDuration(item, index, songsMap);
    final displayText = duration != null ? '${item.label} - $duration' : item.label;

    return Container(
      key: ValueKey('divider_${item.id}_$index'),
      margin: const EdgeInsets.symmetric(vertical: 2),
      height: 36,
      decoration: BoxDecoration(
        color: dividerColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          // Selection checkbox or drag handle
          if (_isSelectionMode)
            Checkbox(
              value: _selectedItems.contains(item.id),
              onChanged: _isLoading
                  ? null
                  : (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedItems.add(item.id);
                        } else {
                          _selectedItems.remove(item.id);
                        }
                      });
                    },
              activeColor: Colors.white,
              checkColor: const Color(0xFF0468cc),
            )
          else
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.drag_indicator,
                  color: _getContrastColor(dividerColor),
                  size: 16,
                ),
              ),
            ),
          Expanded(
            child: Text(
              displayText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _getContrastColor(dividerColor),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Delete button (only in non-selection mode)
          if (!_isSelectionMode)
            IconButton(
              onPressed: _isLoading ? null : () => _removeItem(index),
              icon: Icon(
                Icons.remove_circle,
                size: 18,
                color: _getContrastColor(dividerColor),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  /// Calculate total duration of songs between this divider and the NEXT divider (or end of list)
  /// Returns null if no songs are found between this divider and the next divider
  String? _calculateDividerDuration(SetlistDividerItem divider, int dividerIndex, Map<String, Song> songsMap) {
    // Start index is right after this divider
    final startIndex = dividerIndex + 1;
    
    // Find the end index (next divider or end of list)
    int endIndex = _items.length;
    for (int i = dividerIndex + 1; i < _items.length; i++) {
      if (_items[i] is SetlistDividerItem) {
        endIndex = i;
        break;
      }
    }

    // Sum durations of songs between startIndex and endIndex
    int totalSeconds = 0;
    bool foundSongs = false;
    for (int i = startIndex; i < endIndex; i++) {
      final item = _items[i];
      if (item is SetlistSongItem) {
        final song = songsMap[item.songId];
        if (song?.duration != null) {
          totalSeconds += _parseDurationToSeconds(song!.duration!);
          foundSongs = true;
        }
      }
    }

    // Return null if no songs were found between this divider and the next
    if (!foundSongs) return null;

    // Format as MM:SS
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _parseDurationToSeconds(String duration) {
    final parts = duration.split(':');
    if (parts.length != 2) return 0;
    
    final minutes = int.tryParse(parts[0]) ?? 0;
    final seconds = int.tryParse(parts[1]) ?? 0;
    
    return (minutes * 60) + seconds;
  }

  Color _parseColor(String colorString) {
    // Convert color name to Color object
    switch (colorString.toLowerCase()) {
      case 'red':
        return const Color(0xFFF44336);
      case 'green':
        return const Color(0xFF4CAF50);
      case 'orange':
        return const Color(0xFFFF9800);
      case 'purple':
        return const Color(0xFF9C27B0);
      case 'teal':
        return const Color(0xFF009688);
      case 'yellow':
        return const Color(0xFFFFEB3B);
      case 'pink':
        return const Color(0xFFE91E63);
      case 'blue':
      default:
        return const Color(0xFF2196F3);
    }
  }

  Color _getContrastColor(Color backgroundColor) {
    // Calculate luminance to determine if we should use white or black text
    final luminance = backgroundColor.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
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

  Widget _buildTotalDivider(Setlist? setlist, Map<String, Song> songsMap) {
    if (setlist == null) return const SizedBox.shrink();
    
    final totalDuration = _calculateTotalSetlistDuration(setlist, songsMap);

    // Use default theme color (blue)
    final dividerColor = const Color(0xFF2196F3);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      height: 36,
      decoration: BoxDecoration(
        color: dividerColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(
          'Total: $totalDuration',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _getContrastColor(dividerColor),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Calculate total duration of all songs in the setlist
  String _calculateTotalSetlistDuration(Setlist setlist, Map<String, Song> songsMap) {
    int totalSeconds = 0;
    for (final item in setlist.items) {
      if (item is SetlistSongItem) {
        final song = songsMap[item.songId];
        if (song?.duration != null) {
          totalSeconds += _parseDurationToSeconds(song!.duration!);
        }
      }
    }

    // Format as HH:MM:SS
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildAddButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: StandardWideButton(
        label: 'Add...',
        icon: Icons.add,
        onPressed: () async {
          if (_isLoading) return;
          _showAddDrawer();
        },
      ),
    );
  }
}
