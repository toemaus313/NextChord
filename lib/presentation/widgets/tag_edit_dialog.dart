import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/song_provider.dart';

class TagEditDialog extends StatefulWidget {
  final String title;
  final Set<String> initialTags;
  final Function(List<String>) onTagsUpdated;

  const TagEditDialog({
    Key? key,
    required this.title,
    required this.initialTags,
    required this.onTagsUpdated,
  }) : super(key: key);

  @override
  State<TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends State<TagEditDialog> {
  late final TextEditingController _controller;
  late final Set<String> _currentTags;
  final Set<String> _tagsToAdd = {};
  final Set<String> _tagsToRemove = {};
  late final FocusNode _okButtonFocusNode;
  late final FocusNode _textFieldFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _okButtonFocusNode = FocusNode();
    _textFieldFocusNode = FocusNode();
    _currentTags = Set<String>.from(widget.initialTags);
    
    // Auto-focus the text field when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _textFieldFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _okButtonFocusNode.dispose();
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  /// Save and close the dialog
  void _saveAndClose(StateSetter setState) {
    // Calculate final tags
    final finalTags = <String>{};
    finalTags.addAll(_currentTags.where((tag) => !_tagsToRemove.contains(tag)));
    finalTags.addAll(_tagsToAdd);
    
    Navigator.pop(context, true);
    widget.onTagsUpdated(finalTags.toList());
  }

  /// Get color for a tag based on whether it's an instrument tag
  (Color, Color) _getTagColors(String tag) {
    const instrumentTags = {'Acoustic', 'Electric', 'Piano', 'Guitar', 'Bass', 'Drums', 'Vocals', 'Instrumental'};
    
    if (instrumentTags.contains(tag)) {
      return (Colors.orange.withValues(alpha: 0.2), Colors.orange);
    } else {
      return (Theme.of(context).colorScheme.primaryContainer, Theme.of(context).colorScheme.onPrimaryContainer);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        // Get matching suggestions based on input
        final inputText = _controller.text.trim();
        final suggestions = inputText.isEmpty 
            ? <String>[]
            : context.read<SongProvider>().allTags
                .where((tag) => 
                    tag.toLowerCase().contains(inputText.toLowerCase()) &&
                    !_currentTags.contains(tag) &&
                    !_tagsToAdd.contains(tag))
                .take(5)
                .toList();
        
        return Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && _textFieldFocusNode.hasFocus) {
            // Handle TAB to accept suggestions
            if (event.logicalKey == LogicalKeyboardKey.tab) {
              if (_controller.text.trim().isNotEmpty && suggestions.isNotEmpty) {
                // TAB accepts the first suggestion when there's input
                setState(() {
                  _tagsToAdd.add(suggestions.first);
                  _controller.clear();
                });
                // Keep focus on text field
                Future.microtask(() => _textFieldFocusNode.requestFocus());
                return KeyEventResult.handled;
              }
            }
            
            // Handle ENTER to save the dialog
            if (event.logicalKey == LogicalKeyboardKey.enter) {
              _saveAndClose(setState);
              return KeyEventResult.handled;
            }
          }
          
          return KeyEventResult.ignored;
        },
        child: AlertDialog(
          title: Text(widget.title),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current tags section
                if (_currentTags.isNotEmpty || _tagsToAdd.isNotEmpty) ...[
                  const Text(
                    'Current Tags:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      // Show current tags (not removed)
                      ..._currentTags
                          .where((tag) => !_tagsToRemove.contains(tag))
                          .map((tag) {
                            final (bgColor, textColor) = _getTagColors(tag);
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: textColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tag,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _tagsToRemove.add(tag);
                                      });
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 14,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      // Show tags to be added
                      ..._tagsToAdd.map((tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _tagsToAdd.remove(tag);
                                });
                              },
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // Add new tag section
                const Text(
                  'Add Tags:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Focus(
                  focusNode: _textFieldFocusNode,
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type to search or create new tag...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                    onSubmitted: (value) {
                      // ENTER now saves the dialog
                      _saveAndClose(setState);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Tab to accept suggestion, Enter to save\n• Use commas to add multiple tags at once\n• All tags are case-insensitive',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                // Suggestions
                if (suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Suggestions:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: suggestions.map((tag) => GestureDetector(
                      onTap: () {
                        setState(() {
                          _tagsToAdd.add(tag);
                          _controller.clear();
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            Focus(
              focusNode: _okButtonFocusNode,
              canRequestFocus: false,
              skipTraversal: true,
              child: FilledButton(
                onPressed: () {
                  // Calculate final tags
                  final finalTags = <String>{};
                  finalTags.addAll(_currentTags.where((tag) => !_tagsToRemove.contains(tag)));
                  finalTags.addAll(_tagsToAdd);
                  
                  Navigator.pop(context, true);
                  widget.onTagsUpdated(finalTags.toList());
                },
                child: const Text('OK'),
              ),
            ),
            Focus(
              canRequestFocus: false,
              skipTraversal: true,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      );
      },
    );
  }
}
