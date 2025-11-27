import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/entities/setlist.dart';
import '../../../domain/entities/song.dart';

/// Controller for managing setlist editor state and logic
class SetlistEditorController extends ChangeNotifier {
  final Setlist? setlist;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  String? _imagePath;
  List<SetlistItem> _items = [];
  bool _hasUnsavedChanges = false;

  // Original values for comparison
  late final String _originalName;
  late final String _originalNotes;
  late final String? _originalImagePath;
  late final List<SetlistItem> _originalItems;

  SetlistEditorController({this.setlist}) {
    _initializeFromSetlist();
  }

  void _initializeFromSetlist() {
    if (setlist != null) {
      _originalName = setlist!.name;
      _originalNotes = setlist!.notes;
      _originalImagePath = setlist!.imagePath;
      _originalItems = List.from(setlist!.items);

      nameController.text = _originalName;
      notesController.text = _originalNotes;
      _imagePath = _originalImagePath;
      _items = List.from(_originalItems);
    } else {
      _originalName = '';
      _originalNotes = '';
      _originalImagePath = null;
      _originalItems = [];

      _items = [];
    }

    // Add listeners to track changes
    nameController.addListener(_onFormChanged);
    notesController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    final currentName = nameController.text;
    final currentNotes = notesController.text;

    _hasUnsavedChanges = currentName != _originalName ||
        currentNotes != _originalNotes ||
        _imagePath != _originalImagePath ||
        !listEquals(_items, _originalItems);

    notifyListeners();
  }

  // Getters
  String? get imagePath => _imagePath;
  List<SetlistItem> get items => List.unmodifiable(_items);
  bool get hasUnsavedChanges => _hasUnsavedChanges;
  bool get isValid => nameController.text.trim().isNotEmpty;

  // Setters
  void setImagePath(String? path) {
    _imagePath = path;
    _onFormChanged();
  }

  void setItems(List<SetlistItem> items) {
    _items = List.from(items);
    _onFormChanged();
  }

  void addItem(SetlistItem item) {
    _items.add(item);
    _onFormChanged();
  }

  void removeItemAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      _onFormChanged();
    }
  }

  void moveItem(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _items.removeAt(oldIndex);
    _items.insert(newIndex, item);
    _onFormChanged();
  }

  void updateItemAt(int index, SetlistItem item) {
    if (index >= 0 && index < _items.length) {
      _items[index] = item;
      _onFormChanged();
    }
  }

  void addDivider(String text) {
    final divider = SetlistDividerItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      order: items.length,
      label: text,
    );
    addItem(divider);
  }

  void addSongs(List<Song> songs) {
    for (final song in songs) {
      final songItem = SetlistSongItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        order: _items.length,
        songId: song.id,
      );
      addItem(songItem);
    }
  }

  Setlist createSetlist() {
    return Setlist(
      id: setlist?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      items: List.from(_items),
      notes: notesController.text.trim().isEmpty
          ? ''
          : notesController.text.trim(),
      imagePath: _imagePath,
      createdAt: setlist?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Validate the form and return true if valid
  bool validateForm() {
    if (nameController.text.trim().isEmpty) {
      return false;
    }
    return true;
  }

  /// Build the setlist from current form data
  Setlist buildSetlist() {
    return createSetlist();
  }

  void restoreOriginalValues() {
    nameController.text = _originalName;
    notesController.text = _originalNotes;
    _imagePath = _originalImagePath;
    _items = List.from(_originalItems);
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  void reset() {
    nameController.clear();
    notesController.clear();
    _imagePath = null;
    _items = [];
    _hasUnsavedChanges = false;
    notifyListeners();
  }

  @override
  void dispose() {
    nameController.dispose();
    notesController.dispose();
    super.dispose();
  }
}
