import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

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
          _isEditing ? 'Edit setlist' : 'New setlist',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: _isSaving ? null : _saveSetlist,
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
          child: Text(
            _isEditing ? 'Save' : 'Save',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      textAlign: TextAlign.center,
      textAlignVertical: TextAlignVertical.center,
      decoration: InputDecoration(
        hintText: 'Setlist Title',
        hintStyle:
            TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
        filled: false,
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
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Name is required';
        }
        return null;
      },
    );
  }

  Widget _buildImagePicker(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isSaving ? null : _selectImage,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24, width: 1.5),
                color: Colors.black.withAlpha(30),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _imagePath == null
                    ? _buildImagePlaceholder()
                    : _buildImagePreview(_imagePath!),
              ),
            ),
          ),
        ),
        if (_imagePath != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isSaving
                ? null
                : () {
                    setState(() => _imagePath = null);
                  },
            icon: const Icon(Icons.delete_forever, color: Colors.white70),
            label: const Text(
              'Remove image',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSetlistSpecificToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Setlist-specific edits',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.7,
            child: Switch(
              value: _setlistSpecificEditsEnabled,
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFF00D9FF),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: _isSaving
                  ? null
                  : (value) {
                      setState(() => _setlistSpecificEditsEnabled = value);
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSongsSection(
    BuildContext context,
    Map<String, Song> songsMap,
  ) {
    final textColor = Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'ITEMS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              '${_items.length} song${_items.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_items.isEmpty)
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.queue_music,
                        color: Colors.white.withValues(alpha: 0.6), size: 48),
                    const SizedBox(height: 8),
                    const Text(
                      'No songs yet',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Tap Add Song to build your set',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 10),
                    _buildAddSongButton(),
                  ],
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _items.length,
                onReorder: _onReorder,
                buildDefaultDragHandles: false,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  final song = songsMap[item.songId];
                  return _buildSongTile(item, song, index);
                },
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: _buildAddSongButton(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSongTile(SetlistSongItem item, Song? song, int index) {
    final title = song?.title ?? 'Unknown song';
    final artist = song?.artist ?? '';
    final subtitle = artist.isNotEmpty
        ? artist
        : (song == null ? 'Song not found in library' : '');

    return Container(
      key: ValueKey('${item.songId}_$index'),
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: ListTile(
        dense: true,
        leading: IconButton(
          tooltip: 'Remove',
          onPressed: _isSaving
              ? null
              : () => setState(() {
                    _items.removeAt(index);
                    _normalizeOrders();
                  }),
          icon: const Icon(Icons.delete, color: Colors.redAccent),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        subtitle: subtitle.isNotEmpty
            ? Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              )
            : null,
        trailing: ReorderableDragStartListener(
          index: index,
          child: const Icon(Icons.drag_indicator, color: Colors.white70),
        ),
      ),
    );
  }

  Widget _buildAddSongButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0468cc),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: _isSaving ? null : _openAddSongSheet,
      icon: const Icon(Icons.add, size: 16),
      label: const Text(
        'Add ...',
        style: TextStyle(fontSize: 12),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {required IconData icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      prefixIcon: Icon(icon, color: Colors.white70, size: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }

  Future<void> _openAddSongSheet() async {
    final songProvider = context.read<SongProvider>();
    final songs = songProvider.songs;

    if (songs.isEmpty) {
      if (!songProvider.isLoading) {
        await songProvider.loadSongs();
      }
    }

    final selectedSongId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.7,
          child: Column(
            children: [
              ListTile(
                title: const Text('Add Song to Setlist'),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const Divider(height: 0),
              Expanded(
                child: songs.isEmpty && songProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          final alreadyAdded =
                              _items.any((item) => item.songId == song.id);
                          return ListTile(
                            enabled: !alreadyAdded,
                            title: Text(song.title),
                            subtitle: Text(song.artist),
                            trailing: alreadyAdded
                                ? const Icon(Icons.check, color: Colors.green)
                                : const Icon(Icons.add),
                            onTap: alreadyAdded
                                ? null
                                : () => Navigator.of(context).pop(song.id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );

    if (selectedSongId != null) {
      setState(() {
        _items.add(
          SetlistSongItem(
            songId: selectedSongId,
            order: _items.length,
          ),
        );
      });
    }
  }

  Future<void> _selectImage() async {
    try {
      debugPrint('SetlistEditor: _selectImage called');
      const imageTypeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['png', 'jpg', 'jpeg', 'webp'],
        mimeTypes: ['image/png', 'image/jpeg', 'image/webp'],
      );

      debugPrint('SetlistEditor: About to call openFile with imageTypeGroup');
      final selectedFile = await openFile(acceptedTypeGroups: [imageTypeGroup]);
      debugPrint(
          'SetlistEditor: openFile returned: ${selectedFile?.path ?? 'null'}');
      if (selectedFile == null) {
        debugPrint('SetlistEditor: No file selected');
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
        debugPrint(
            'SetlistEditor: Resizing image from ${width}x$height to 200x200');
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
      debugPrint('SetlistEditor: Exception in _selectImage: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.image_outlined, color: Colors.white54, size: 42),
          SizedBox(height: 8),
          Text(
            'Tap to add image',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    final file = File(path);
    return file.existsSync()
        ? Image.file(file, fit: BoxFit.cover)
        : _buildImagePlaceholder();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      _normalizeOrders();
    });
  }

  void _normalizeOrders() {
    _items = [
      for (int i = 0; i < _items.length; i++) _items[i].copyWith(order: i),
    ];
  }

  Future<void> _saveSetlist() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final provider = context.read<SetlistProvider>();
      final now = DateTime.now();

      final setlist = Setlist(
        id: widget.setlist?.id ?? '',
        name: _nameController.text.trim(),
        items: _items,
        // Notes are no longer editable in this compact dialog; preserve existing
        // notes when editing, otherwise leave null.
        notes: widget.setlist?.notes,
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
}
