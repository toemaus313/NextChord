import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/setlist.dart';
import '../../domain/entities/song.dart';
import '../providers/setlist_provider.dart';
import '../providers/song_provider.dart';

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

    final selectedSongIds = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (builderContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0468cc),
                        Color.fromARGB(150, 3, 73, 153)
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle bar
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(100),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Add Songs to Setlist',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      // Search box
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Consumer<SongProvider>(
                          builder: (context, provider, child) {
                            return TextField(
                              controller: searchController,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Search by title, artist, or tags...',
                                hintStyle: TextStyle(
                                    color: Colors.white.withAlpha(150)),
                                prefixIcon: const Icon(Icons.search,
                                    color: Colors.white70),
                                suffixIcon: searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            color: Colors.white70),
                                        onPressed: () {
                                          searchController.clear();
                                          provider.searchSongs('');
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: Colors.white24),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: Colors.white24),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide:
                                      const BorderSide(color: Colors.white),
                                ),
                              ),
                              onChanged: (value) {
                                provider.searchSongs(value);
                              },
                            );
                          },
                        ),
                      ),
                      // Selection controls
                      Consumer<SongProvider>(
                        builder: (context, provider, child) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                // Checkbox to toggle selection mode
                                IconButton(
                                  icon: Icon(
                                    provider.selectionMode
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      provider.toggleSelectionMode(),
                                  tooltip: provider.selectionMode
                                      ? 'Exit selection'
                                      : 'Select songs',
                                ),
                                // Select all/none buttons
                                if (provider.selectionMode) ...[
                                  TextButton(
                                    onPressed: () => provider.selectAll(),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Select All'),
                                  ),
                                  TextButton(
                                    onPressed: () => provider.deselectAll(),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Clear'),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${provider.selectedSongs.length} selected',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                      // Songs list
                      Expanded(
                        child: Consumer<SongProvider>(
                          builder: (context, provider, child) {
                            if (provider.isLoading) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              );
                            }

                            if (provider.songs.isEmpty) {
                              return const Center(
                                child: Text(
                                  'No songs found',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: scrollController,
                              itemCount: provider.songs.length,
                              itemBuilder: (context, index) {
                                final song = provider.songs[index];
                                final isSelected = provider.selectedSongs
                                    .any((s) => s.id == song.id);

                                return ListTile(
                                  leading: provider.selectionMode
                                      ? Checkbox(
                                          value: isSelected,
                                          onChanged: (value) {
                                            provider
                                                .toggleSongSelection(song.id);
                                          },
                                          fillColor: WidgetStateProperty.all(
                                              Colors.white),
                                          checkColor: Colors.black,
                                        )
                                      : CircleAvatar(
                                          radius: 20,
                                          backgroundColor:
                                              Colors.white.withAlpha(30),
                                          child: Text(
                                            song.title.isNotEmpty
                                                ? song.title[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                  title: Text(
                                    song.title,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    song.artist,
                                    style: TextStyle(
                                        color: Colors.white.withAlpha(150)),
                                  ),
                                  trailing: song.key.isNotEmpty
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withAlpha(30),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            song.key,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        )
                                      : null,
                                  tileColor: isSelected
                                      ? Colors.white.withAlpha(50)
                                      : Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  onTap: provider.selectionMode
                                      ? () =>
                                          provider.toggleSongSelection(song.id)
                                      : () {
                                          // Single selection mode - add this song directly
                                          Navigator.of(context).pop([song.id]);
                                        },
                                  selected: isSelected,
                                );
                              },
                            );
                          },
                        ),
                      ),
                      // Add selected button
                      Consumer<SongProvider>(
                        builder: (context, provider, child) {
                          if (!provider.selectionMode ||
                              provider.selectedSongs.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          return Container(
                            padding: const EdgeInsets.all(16),
                            child: ElevatedButton(
                              onPressed: () {
                                final selectedIds = provider.selectedSongs
                                    .map((s) => s.id)
                                    .toList();
                                Navigator.of(context).pop(selectedIds);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF0468cc),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                'Add ${provider.selectedSongs.length} Song${provider.selectedSongs.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    searchController.dispose();
    return selectedSongIds;
  }

  @override
  State<SetlistEditorDialog> createState() => _SetlistEditorDialogState();
}

class _SetlistEditorDialogState extends State<SetlistEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late List<SetlistSongItem> _items;
  bool _isSaving = false;
  bool _setlistSpecificEditsEnabled = true;
  String? _imagePath;

  bool get _isEditing => widget.setlist != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.setlist?.name ?? '');
    _imagePath = widget.setlist?.imagePath;
    _setlistSpecificEditsEnabled =
        widget.setlist?.setlistSpecificEditsEnabled ?? true;
    final initialItems = widget.setlist?.items ?? const <SetlistItem>[];
    _items = initialItems.whereType<SetlistSongItem>().toList()
      ..sort((a, b) => a.order.compareTo(b.order));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final songProvider = context.read<SongProvider>();
      if (!songProvider.isLoading && songProvider.songs.isEmpty) {
        songProvider.loadSongs();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final songProvider = context.watch<SongProvider>();
    final songsMap = {
      for (final song in songProvider.songs) song.id: song,
    };

    return Center(
      child: ConstrainedBox(
        // Compact dialog
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 320),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0468cc), Color.fromARGB(150, 3, 73, 153)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(100),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              const SizedBox(height: 8),
              Flexible(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildImagePicker(context),
                        const SizedBox(height: 8),
                        _buildNameField(),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 10),
                        _buildSetlistSpecificToggle(),
                        const SizedBox(height: 10),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 8),
                        _buildSongsSection(context, songsMap),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(fontSize: 14),
          ),
        ),
        const Spacer(),
        Text(
          _isEditing ? 'Edit Setlist' : 'Create Setlist',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        FilledButton(
          onPressed: _isSaving ? null : _saveSetlist,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0468cc),
            padding: const EdgeInsets.symmetric(horizontal: 21, vertical: 11),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Color(0xFF0468cc)),
                  ),
                )
              : Text(
                  _isEditing ? 'Save' : 'Create',
                  style: const TextStyle(fontSize: 14),
                ),
        ),
      ],
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    return GestureDetector(
      onTap: _selectImage,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: _imagePath != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_imagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _buildImagePlaceholder(),
                ),
              )
            : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate, color: Colors.white70, size: 32),
          SizedBox(height: 8),
          Text(
            'Tap to add image',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: 'Setlist Name',
        labelStyle: TextStyle(color: Colors.white.withAlpha(150)),
        hintText: 'Enter setlist name',
        hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
        filled: true,
        fillColor: Colors.white.withAlpha(20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter a setlist name';
        }
        return null;
      },
    );
  }

  Widget _buildSetlistSpecificToggle() {
    return Row(
      children: [
        Switch(
          value: _setlistSpecificEditsEnabled,
          onChanged: (value) {
            setState(() {
              _setlistSpecificEditsEnabled = value;
            });
          },
          activeColor: Colors.white,
          activeTrackColor: Colors.white.withAlpha(100),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Setlist-specific edits',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Allow song changes that apply only to this setlist',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSongsSection(BuildContext context, Map<String, Song> songsMap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Songs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addSongs,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Songs', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'No songs added yet',
              style: TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            onReorder: _onReorderSongs,
            buildDefaultDragHandles: false,
            itemBuilder: (context, index) {
              final item = _items[index];
              final song = songsMap[item.songId];
              return _buildSongItem(item, song, index);
            },
          ),
      ],
    );
  }

  Widget _buildSongItem(SetlistSongItem item, Song? song, int index) {
    return Container(
      key: ValueKey(item.songId),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_handle, color: Colors.white54, size: 20),
        ),
        title: Text(
          song?.title ?? 'Unknown Song',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        subtitle: song?.artist.isNotEmpty == true
            ? Text(
                song!.artist,
                style:
                    TextStyle(color: Colors.white.withAlpha(150), fontSize: 12),
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.remove_circle,
              color: Colors.redAccent, size: 20),
          onPressed: () => _removeSong(index),
        ),
      ),
    );
  }

  Future<void> _selectImage() async {
    try {
      const imageTypeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['png', 'jpg', 'jpeg', 'webp'],
        mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
      );

      final selectedFile = await openFile(acceptedTypeGroups: [imageTypeGroup]);
      if (selectedFile == null) {
        return;
      }

      final bytes = await selectedFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final originalImage = frame.image;
      final width = originalImage.width;
      final height = originalImage.height;

      Uint8List resizedBytes;
      if (width != 200 || height != 200) {
        final resizedBytesData = await _resizeImage(originalImage, 200, 200);
        resizedBytes = resizedBytesData;
      } else {
        resizedBytes = bytes;
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final setlistDir = Directory(p.join(docsDir.path, 'setlist_images'));
      if (!await setlistDir.exists()) {
        await setlistDir.create(recursive: true);
      }
      final originalPath = selectedFile.path;
      final originalExtension =
          originalPath.isNotEmpty ? p.extension(originalPath) : '';
      final extension =
          originalExtension.isNotEmpty ? originalExtension : '.png';
      final fileName =
          'setlist_${DateTime.now().millisecondsSinceEpoch}$extension';
      final savedPath = p.join(setlistDir.path, fileName);
      final savedFile = File(savedPath);
      await savedFile.writeAsBytes(resizedBytes);

      setState(() {
        _imagePath = savedPath;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Uint8List> _resizeImage(
      ui.Image originalImage, int targetWidth, int targetHeight) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the image scaled to fit the target size
    canvas.drawImageRect(
      originalImage,
      Rect.fromLTWH(0, 0, originalImage.width.toDouble(),
          originalImage.height.toDouble()),
      Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
      Paint(),
    );

    final picture = recorder.endRecording();
    final resizedImage = await picture.toImage(targetWidth, targetHeight);
    final byteData =
        await resizedImage.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<void> _addSongs() async {
    final selectedSongIds =
        await SetlistEditorDialog.showAddSongs(context, _items);

    if (!mounted || selectedSongIds == null || selectedSongIds.isEmpty) {
      return;
    }

    setState(() {
      for (final songId in selectedSongIds) {
        if (_items.any((item) => item.songId == songId)) {
          continue;
        }
        _items.add(SetlistSongItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          songId: songId,
          order: _items.length,
        ));
      }
    });
  }

  void _removeSong(int index) {
    setState(() {
      _items.removeAt(index);
      // Normalize orders
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(order: i);
      }
    });
  }

  void _onReorderSongs(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      // Normalize orders
      for (int i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(order: i);
      }
    });
  }

  Future<void> _saveSetlist() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final provider = context.read<SetlistProvider>();
      final now = DateTime.now();

      final setlist = Setlist(
        id: widget.setlist?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        items: _items.cast<SetlistItem>(),
        notes: '',
        imagePath: _imagePath,
        setlistSpecificEditsEnabled: _setlistSpecificEditsEnabled,
        createdAt: widget.setlist?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEditing) {
        await provider.updateSetlist(setlist);
      } else {
        await provider.addSetlist(setlist);
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save setlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
