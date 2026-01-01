import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/setlist.dart';
import '../../domain/entities/song.dart';
import '../../data/repositories/setlist_repository.dart';

/// Service for managing setlists
class SetlistService {
  final SetlistRepository _repository;
  final Uuid _uuid = const Uuid();

  SetlistService(this._repository);

  /// Load all setlists from the database
  Future<List<Setlist>> loadSetlists() async {
    try {
      final setlists = await _repository.getAllSetlists();
      return setlists;
    } catch (e) {
      rethrow;
    }
  }

  /// Save a setlist to the database
  Future<void> saveSetlist({
    required String name,
    required String description,
    required List<SetlistItem> items,
    String? imagePath,
    String? id,
    DateTime? createdAt,
  }) async {
    try {
      final setlist = Setlist(
        id: id ?? _uuid.v4(),
        name: name,
        items: items,
        notes: description,
        imagePath: imagePath,
        createdAt: createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (id == null) {
        await _repository.insertSetlist(setlist);
      } else {
        await _repository.updateSetlist(setlist);
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete a setlist from the database
  Future<void> deleteSetlist(String setlistId) async {
    try {
      await _repository.deleteSetlist(setlistId);
    } catch (e) {
      rethrow;
    }
  }

  /// Pick an image file for setlist cover
  Future<String?> pickImage([BuildContext? context]) async {
    try {
      // Check if we're on a mobile platform (iOS/Android)
      final isMobile = Platform.isIOS || Platform.isAndroid;

      if (isMobile) {
        // On iOS, show a dialog with multiple options
        if (Platform.isIOS && context != null) {
          return await _pickImageIOS(context);
        } else {
          // Android: use image_picker for photo library
          final ImagePicker picker = ImagePicker();
          final XFile? image = await picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );

          if (image != null) {
            return image.path;
          }
        }
      } else {
        // Desktop platforms: use file_picker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );

        if (result != null && result.files.isNotEmpty) {
          return result.files.first.path;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// iOS-specific image picker with multiple source options
  Future<String?> _pickImageIOS(BuildContext context) async {
    // Check if clipboard has image data
    bool hasClipboardImage = false;
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      // For now, we'll check if there's any clipboard data at all
      // In a more advanced implementation, you'd need to check specifically for image data
      hasClipboardImage = clipboardData?.text?.isNotEmpty == true;
    } catch (e) {
      hasClipboardImage = false;
    }

    // Show dialog with options
    final ImageSource? selectedSource = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Choose from Files
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Choose from Files'),
                onTap: () => Navigator.of(context).pop(null), // null = files
              ),
              // Add Photo (Photo Library)
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Add Photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
              // Take Photo (Camera)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              // Add from Clipboard
              ListTile(
                leading: const Icon(Icons.content_paste),
                title: const Text('Add from Clipboard'),
                enabled: hasClipboardImage,
                onTap: hasClipboardImage
                    ? () => Navigator.of(context).pop(ImageSource.values.length
                        as ImageSource?) // Use a sentinel value
                    : null,
              ),
            ],
          ),
        );
      },
    );

    if (selectedSource == null) {
      // Choose from Files
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      return result?.files.first.path;
    } else if (selectedSource == ImageSource.gallery ||
        selectedSource == ImageSource.camera) {
      // Photo Library or Camera
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: selectedSource,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      return image?.path;
    } else {
      // Clipboard (our sentinel value)
      return await _pickImageFromClipboard();
    }
  }

  /// Get image from clipboard
  Future<String?> _pickImageFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text?.isNotEmpty == true) {
        // For now, we'll treat text as if it could be an image URL or data
        // In a full implementation, you'd need to handle different clipboard formats
        // This is a placeholder for clipboard image functionality
        return null; // Not implemented yet
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Save image to app documents directory and return the path
  Future<String?> saveImageToAppDirectory(String? sourcePath) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;

    try {
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        return null;
      }

      final documentsDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(documentsDir.path, 'setlist_images'));

      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = 'setlist_${_uuid.v4()}.jpg';
      final savedImagePath = p.join(imagesDir.path, fileName);

      // Copy and optimize the image
      final savedFile = await sourceFile.copy(savedImagePath);

      // If it's a large image, we could resize it here
      // For now, just copy as-is
      return savedFile.path;
    } catch (e) {
      return null;
    }
  }

  /// Delete image file from app directory
  Future<void> deleteImageFile(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;

    try {
      final imageFile = File(imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } catch (e) {}
  }

  /// Load image file as bytes for display
  Future<Uint8List?> loadImageBytes(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        return null;
      }

      return await imageFile.readAsBytes();
    } catch (e) {
      return null;
    }
  }

  /// Validate setlist data
  String? validateSetlist({
    required String name,
    required List<SetlistItem> items,
  }) {
    if (name.trim().isEmpty) {
      return 'Please enter a setlist name';
    }

    // Check if there are any song items
    final hasSongs = items.any((item) => item is SetlistSongItem);
    if (!hasSongs) {
      return 'Please add at least one song to the setlist';
    }

    return null; // No validation errors
  }

  /// Create setlist song items from song IDs
  List<SetlistSongItem> createSetlistSongItems(
    List<String> songIds,
    List<Song> availableSongs,
  ) {
    final songMap = {for (var song in availableSongs) song.id: song};

    return songIds.asMap().entries.map((entry) {
      final id = entry.key;
      final songId = entry.value;
      final song = songMap[songId];

      if (song == null) {
        // Song not found, create a placeholder
        return SetlistSongItem(
          id: _uuid.v4(),
          order: id,
          songId: songId,
          transposeSteps: 0,
          capo: 0,
        );
      }

      return SetlistSongItem(
        id: _uuid.v4(),
        order: id,
        songId: song.id,
        transposeSteps: 0,
        capo: 0,
      );
    }).toList();
  }

  /// Update song items with new data
  List<SetlistSongItem> updateSongItems(
    List<SetlistSongItem> items,
    List<Song> availableSongs,
  ) {
    // Since SetlistSongItem doesn't store title/artist directly,
    // we just return the items as they are
    // The UI will look up song details from the availableSongs list
    return items;
  }
}
