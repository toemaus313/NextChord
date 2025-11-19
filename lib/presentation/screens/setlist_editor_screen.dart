import 'package:flutter/material.dart';
import '../../domain/entities/song.dart';

/// Screen for creating/editing a setlist
/// TODO: Implement full functionality with song ordering, image upload, and setlist-specific settings
class SetlistEditorScreen extends StatefulWidget {
  final Setlist? setlist;

  const SetlistEditorScreen({Key? key, this.setlist}) : super(key: key);

  @override
  State<SetlistEditorScreen> createState() => _SetlistEditorScreenState();
}

class _SetlistEditorScreenState extends State<SetlistEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  bool get isEditing => widget.setlist != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.setlist?.name ?? '');
    _notesController = TextEditingController(text: widget.setlist?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Setlist' : 'New Setlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveSetlist,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Setlist Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            const Text(
              'Full editor functionality coming soon:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Add/remove songs'),
            const Text('• Reorder songs (drag & drop)'),
            const Text('• Set transpose/capo per song'),
            const Text('• Upload 200x200px image'),
            const Text('• Add section dividers'),
          ],
        ),
      ),
    );
  }

  void _saveSetlist() {
    // TODO: Implement save functionality
    Navigator.pop(context, true);
  }
}
