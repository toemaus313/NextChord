import 'dart:convert';

import 'package:uuid/uuid.dart';
import '../../domain/entities/setlist.dart';
import '../database/app_database.dart';
import '../../core/services/database_change_service.dart';
import 'package:nextchord/main.dart' as main;

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
      setlistSpecificEditsEnabled: true,
      isDeleted: setlist.isDeleted,
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
      notes: model.notes ?? '',
      imagePath: model.imagePath,
      createdAt: DateTime.fromMillisecondsSinceEpoch(model.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(model.updatedAt),
    );
  }

  /// Serialize setlist items to JSON-compatible format
  List<Map<String, dynamic>> _serializeItems(List<SetlistItem> items) {
    final serialized = items.map((item) {
      if (item is SetlistSongItem) {
        return {
          'type': 'song',
          'songId': item.songId,
          'order': item.order,
          'transposeSteps': item.transposeSteps,
          'capo': item.capo,
        };
      } else if (item is SetlistDividerItem) {
        final colorValue = item.color;
        return {
          'type': 'divider',
          'label': item.label,
          'order': item.order,
          'color': colorValue,
        };
      }
      throw Exception('Unknown SetlistItem type');
    }).toList();
    return serialized;
  }

  /// Deserialize JSON to setlist items
  List<SetlistItem> _deserializeItems(String itemsJson) {
    try {
      final List<dynamic> itemsList = jsonDecode(itemsJson);
      final parsedItems = itemsList
          .map((item) {
            final type = item['type'] as String;
            if (type == 'song') {
              return SetlistSongItem(
                id: item['id'] as String? ?? Uuid().v4(),
                songId: item['songId'] as String,
                order: item['order'] as int,
                transposeSteps: item['transposeSteps'] as int? ?? 0,
                capo: item['capo'] as int? ?? 0,
              );
            } else if (type == 'divider') {
              final colorValue = item['color'] as int? ?? 0xFFFFFFFF;
              final color = '#${colorValue.toRadixString(16).padLeft(8, '0')}';
              return SetlistDividerItem(
                id: item['id'] as String? ?? Uuid().v4(),
                label: item['label'] as String,
                order: item['order'] as int,
                color: color,
              );
            }
            return null as SetlistItem?;
          })
          .whereType<SetlistItem>()
          .toList();
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
      final models = await _db.getAllSetlists();
      final setlists = models.map(_modelToSetlist).toList();
      return setlists;
    } catch (e) {
      return [];
    }
  }

  /// Fetch a single setlist by ID
  Future<Setlist?> getSetlistById(String id) async {
    try {
      final model = await _db.getSetlistById(id);
      return model != null ? _modelToSetlist(model) : null;
    } catch (e) {
      return null;
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
      await _db.insertSetlist(model);

      // Notify database change for auto-sync
      DatabaseChangeService()
          .notifyDatabaseChanged(table: 'setlists', operation: 'update');

      return setlistToInsert.id;
    } catch (e) {
      return setlist.id; // Return original ID on error
    }
  }

  /// Update an existing setlist
  Future<void> updateSetlist(Setlist setlist) async {
    try {
      final updatedSetlist = setlist.copyWith(updatedAt: DateTime.now());
      final model = _setlistToModel(updatedSetlist);

      await _db.updateSetlist(model);

      // Notify database change for auto-sync
      DatabaseChangeService()
          .notifyDatabaseChanged(table: 'setlists', operation: 'update');
    } catch (e) {
      // Handle error silently
    }
  }

  /// Delete a setlist by ID
  Future<void> deleteSetlist(String id) async {
    try {
      await _db.deleteSetlist(id);
    } catch (e) {
      main.myDebug('[SetlistRepository] deleteSetlist failed: $e');
    }
    DatabaseChangeService()
        .notifyDatabaseChanged(table: 'setlists', operation: 'update');
  }
}
