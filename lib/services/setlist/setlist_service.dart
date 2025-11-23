import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
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
      debugPrint('Loading setlists...');
      final setlists = await _repository.getAllSetlists();
      debugPrint('Loaded ${setlists.length} setlists');
      return setlists;
    } catch (e) {
      debugPrint('Failed to load setlists: $e');
      rethrow;
    }
  }

  /// Save a setlist to the database
  Future<void> saveSetlist({
    required String name,
    required String description,
    required List<SetlistSongItem> songs,
    String? imagePath,
    String? id,
    DateTime? createdAt,
  }) async {
    try {
      debugPrint('Saving setlist: $name');

      // Convert songs to SetlistItem format with order
      final items = songs.asMap().entries.map((entry) {
        return SetlistSongItem(
          id: _uuid.v4(),
          order: entry.key,
          songId: entry.value.songId,
          transposeSteps: entry.value.transposeSteps,
          capo: entry.value.capo,
          text: entry.value.text,
        );
      }).toList();

      final setlist = Setlist(
        id: id ?? _uuid.v4(),
        name: name,
        items: items,
        notes: description,
        imagePath: imagePath,
        setlistSpecificEditsEnabled: true,
        createdAt: createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (id == null) {
        await _repository.insertSetlist(setlist);
      } else {
        await _repository.updateSetlist(setlist);
      }
      debugPrint('Setlist saved successfully');
    } catch (e) {
      debugPrint('Failed to save setlist: $e');
      rethrow;
    }
  }

  /// Delete a setlist from the database
  Future<void> deleteSetlist(String setlistId) async {
    try {
      debugPrint('Deleting setlist: $setlistId');
      await _repository.deleteSetlist(setlistId);
      debugPrint('Setlist deleted successfully');
    } catch (e) {
      debugPrint('Failed to delete setlist: $e');
      rethrow;
    }
  }

  /// Pick an image file for setlist cover
  Future<String?> pickImage() async {
    try {
      debugPrint('Opening image picker...');
      final result = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Images',
            extensions: ['jpg', 'jpeg', 'png', 'gif', 'bmp'],
          ),
        ],
      );

      if (result != null) {
        debugPrint('Image selected: ${result.name}');
        return result.path;
      }
      return null;
    } catch (e) {
      debugPrint('Failed to pick image: $e');
      return null;
    }
  }

  /// Save image to app documents directory and return the path
  Future<String?> saveImageToAppDirectory(String? sourcePath) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;

    try {
      debugPrint('Saving image to app directory...');
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        debugPrint('Source image file does not exist');
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
      debugPrint('Image saved to: ${savedFile.path}');
      return savedFile.path;
    } catch (e) {
      debugPrint('Failed to save image: $e');
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
        debugPrint('Image file deleted: $imagePath');
      }
    } catch (e) {
      debugPrint('Failed to delete image file: $e');
    }
  }

  /// Load image file as bytes for display
  Future<Uint8List?> loadImageBytes(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        debugPrint('Image file does not exist: $imagePath');
        return null;
      }

      return await imageFile.readAsBytes();
    } catch (e) {
      debugPrint('Failed to load image bytes: $e');
      return null;
    }
  }

  /// Validate setlist data
  String? validateSetlist({
    required String name,
    required List<SetlistSongItem> songs,
  }) {
    if (name.trim().isEmpty) {
      return 'Please enter a setlist name';
    }

    if (songs.isEmpty) {
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
