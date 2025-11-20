import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../domain/entities/song.dart';
import '../database/app_database.dart';

/// Repository for managing Setlists
class SetlistRepository {
  final AppDatabase _db;

  SetlistRepository(this._db);

  /// Convert a domain Setlist entity to a database SetlistModel
  SetlistModel _setlistToModel(Setlist setlist) {
    return SetlistModel(
      id: setlist.id,
      name: setlist.name,
      items: jsonEncode(_serializeItems(setlist.items)),
      notes: setlist.notes,
      imagePath: setlist.imagePath,
      setlistSpecificEditsEnabled: setlist.setlistSpecificEditsEnabled,
      createdAt: setlist.createdAt.millisecondsSinceEpoch,
      updatedAt: setlist.updatedAt.millisecondsSinceEpoch,
    );
  }

  /// Convert a database SetlistModel to a domain Setlist entity
  Setlist _modelToSetlist(SetlistModel model) {
    final items = _deserializeItems(model.items);

    return Setlist(
      id: model.id,
      name: model.name,
      items: items,
      notes: model.notes,
      imagePath: model.imagePath,
      setlistSpecificEditsEnabled: model.setlistSpecificEditsEnabled,
      createdAt: DateTime.fromMillisecondsSinceEpoch(model.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(model.updatedAt),
    );
  }

  /// Serialize setlist items to JSON-compatible format
  List<Map<String, dynamic>> _serializeItems(List<SetlistItem> items) {
    return items.map((item) {
      if (item is SetlistSongItem) {
        return {
          'type': 'song',
          'songId': item.songId,
          'order': item.order,
          'transposeSteps': item.transposeSteps,
          'capo': item.capo,
        };
      } else if (item is SetlistDividerItem) {
        return {
          'type': 'divider',
          'label': item.label,
          'order': item.order,
        };
      }
      throw Exception('Unknown SetlistItem type');
    }).toList();
  }

  /// Deserialize JSON to setlist items
  List<SetlistItem> _deserializeItems(String itemsJson) {
    try {
      final List<dynamic> itemsList = jsonDecode(itemsJson);
      final parsedItems = itemsList.map((item) {
        final type = item['type'] as String;
        if (type == 'song') {
          return SetlistSongItem(
            songId: item['songId'] as String,
            order: item['order'] as int,
            transposeSteps: item['transposeSteps'] as int?,
            capo: item['capo'] as int?,
          );
        } else if (type == 'divider') {
          return SetlistDividerItem(
            label: item['label'] as String,
            order: item['order'] as int,
          );
        }
        throw Exception('Unknown item type: $type');
      }).toList();
      parsedItems.sort((a, b) => _itemOrder(a).compareTo(_itemOrder(b)));
      return parsedItems;
    } catch (e) {
      // If parsing fails, return empty list
      return [];
    }
  }

  int _itemOrder(SetlistItem item) {
    if (item is SetlistSongItem) {
      return item.order;
    }
    if (item is SetlistDividerItem) {
      return item.order;
    }
    return 0;
  }

  /// Fetch all setlists
  Future<List<Setlist>> getAllSetlists() async {
    try {
      final models = await _db.setlistsDao.getAllSetlists();
      return models.map(_modelToSetlist).toList();
    } catch (e) {
      throw Exception('Failed to fetch setlists: $e');
    }
  }

  /// Fetch a single setlist by ID
  Future<Setlist?> getSetlistById(String id) async {
    try {
      final model = await _db.setlistsDao.getSetlistById(id);
      return model != null ? _modelToSetlist(model) : null;
    } catch (e) {
      throw Exception('Failed to fetch setlist with ID $id: $e');
    }
  }

  /// Insert a new setlist
  Future<String> insertSetlist(Setlist setlist) async {
    try {
      final setlistToInsert = setlist.id.isEmpty
          ? setlist.copyWith(
              id: const Uuid().v4(),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          : setlist.copyWith(
              updatedAt: DateTime.now(),
            );

      final model = _setlistToModel(setlistToInsert);
      await _db.setlistsDao.insertSetlist(model);
      return setlistToInsert.id;
    } catch (e) {
      throw Exception('Failed to insert setlist: $e');
    }
  }

  /// Update an existing setlist
  Future<void> updateSetlist(Setlist setlist) async {
    try {
      final updatedSetlist = setlist.copyWith(updatedAt: DateTime.now());
      final model = _setlistToModel(updatedSetlist);
      await _db.setlistsDao.updateSetlist(model);
    } catch (e) {
      throw Exception('Failed to update setlist: $e');
    }
  }

  /// Delete a setlist by ID
  Future<void> deleteSetlist(String id) async {
    try {
      await _db.setlistsDao.deleteSetlist(id);
    } catch (e) {
      throw Exception('Failed to delete setlist: $e');
    }
  }
}
