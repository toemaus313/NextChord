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
  late final List<String> _currentTags;
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
    _currentTags = List<String>.from(widget.initialTags);
    
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

  /// Process text input and add tags (handles comma-separated values)
  void _processAndAddTags(String input, StateSetter setState) {
    if (input.trim().isEmpty) return;
    
    // Split by comma and process each tag
    final tags = input.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty);
    
    for (final tag in tags) {
      // Normalize tag (capitalize first letter)
      final normalizedTag = tag[0].toUpperCase() + tag.substring(1).toLowerCase();
      
      // Add if not already present
      if (!_currentTags.contains(normalizedTag) && !_tagsToAdd.contains(normalizedTag)) {
        setState(() {
          _tagsToAdd.add(normalizedTag);
        });
      }
    }
    
    _controller.clear();
  }

  /// Save and close the dialog
  void _saveAndClose(StateSetter setState) {
    // Process any remaining text in the input field
    if (_controller.text.trim().isNotEmpty) {
      _processAndAddTags(_controller.text, setState);
    }
    
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
    const primaryGradientTop = Color(0xFF0468cc);
    const primaryGradientBottom = Color.fromARGB(99, 3, 73, 153);

    return StatefulBuilder(
      builder: (context, setState) {
        // Get the current tag being typed (text after last comma)
        final fullText = _controller.text;
        final lastCommaIndex = fullText.lastIndexOf(',');
        final currentTagText = lastCommaIndex >= 0 
            ? fullText.substring(lastCommaIndex + 1).trim()
            : fullText.trim();
        
        // Get matching suggestions based on current tag being typed
        final suggestions = currentTagText.isEmpty 
            ? <String>[]
            : context.read<SongProvider>().allTags
                .where((tag) => 
                    tag.toLowerCase().contains(currentTagText.toLowerCase()) &&
                    !_currentTags.contains(tag) &&
                    !_tagsToAdd.contains(tag))
                .take(5)
                .toList();
        
        return Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && _textFieldFocusNode.hasFocus) {
            // Handle TAB to accept suggestions or create new tag
            if (event.logicalKey == LogicalKeyboardKey.tab) {
              if (currentTagText.isNotEmpty) {
                if (suggestions.isNotEmpty) {
                  // TAB accepts the first suggestion
                  // First, process any tags before the current one
                  if (lastCommaIndex >= 0) {
                    final tagsBeforeCurrent = fullText.substring(0, lastCommaIndex);
                    if (tagsBeforeCurrent.trim().isNotEmpty) {
                      _processAndAddTags(tagsBeforeCurrent, setState);
                    }
                  }
                  // Then add the suggestion
                  setState(() {
                    _tagsToAdd.add(suggestions.first);
                    _controller.clear();
                  });
                  // Keep focus on text field after state update
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _textFieldFocusNode.requestFocus();
                    }
                  });
                } else {
                  // No suggestions - create new tag(s)
                  _processAndAddTags(_controller.text, setState);
                  // Keep focus on text field after state update
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      _textFieldFocusNode.requestFocus();
                    }
                  });
                }
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
                  _ReorderableTagWrap(
                    spacing: 6,
                    runSpacing: 4,
                    currentTags: _currentTags,
                    tagsToAdd: _tagsToAdd,
                    tagsToRemove: _tagsToRemove,
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        final tag = _currentTags.removeAt(oldIndex);
                        _currentTags.insert(newIndex, tag);
                      });
                    },
                    onRemoveCurrentTag: (tag) {
                      setState(() {
                        _tagsToRemove.add(tag);
                      });
                    },
                    onRemoveNewTag: (tag) {
                      setState(() {
                        _tagsToAdd.remove(tag);
                      });
                    },
                    getTagColors: _getTagColors,
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
                  '• Tab to accept suggestion or create new tag\n• Use commas to add multiple tags at once\n• Enter to save dialog',
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
                          color: primaryGradientTop.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: primaryGradientTop),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: primaryGradientTop,
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
                style: FilledButton.styleFrom(
                  backgroundColor: primaryGradientTop,
                  foregroundColor: Colors.white,
                ),
                child: const Text('OK'),
              ),
            ),
            Focus(
              canRequestFocus: false,
              skipTraversal: true,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: primaryGradientBottom,
                ),
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

/// Reorderable wrap widget for displaying and reordering tags with drag-and-drop
class _ReorderableTagWrap extends StatelessWidget {
  final double spacing;
  final double runSpacing;
  final List<String> currentTags;
  final Set<String> tagsToAdd;
  final Set<String> tagsToRemove;
  final Function(int oldIndex, int newIndex) onReorder;
  final Function(String tag) onRemoveCurrentTag;
  final Function(String tag) onRemoveNewTag;
  final (Color, Color) Function(String tag) getTagColors;

  const _ReorderableTagWrap({
    required this.spacing,
    required this.runSpacing,
    required this.currentTags,
    required this.tagsToAdd,
    required this.tagsToRemove,
    required this.onReorder,
    required this.onRemoveCurrentTag,
    required this.onRemoveNewTag,
    required this.getTagColors,
  });

  @override
  Widget build(BuildContext context) {
    // Build list of current tags (excluding removed ones)
    final visibleCurrentTags = currentTags
        .where((tag) => !tagsToRemove.contains(tag))
        .toList();
    
    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        // Reorderable current tags
        ...visibleCurrentTags.asMap().entries.map((entry) {
          final index = entry.key;
          final tag = entry.value;
          final (bgColor, textColor) = getTagColors(tag);
          
          return DragTarget<int>(
            onWillAcceptWithDetails: (details) {
              return details.data != index;
            },
            onAcceptWithDetails: (details) {
              onReorder(details.data, index);
            },
            builder: (context, candidateData, rejectedData) {
              final isHovered = candidateData.isNotEmpty;
              return Draggable<int>(
                data: index,
                feedback: Opacity(
                  opacity: 0.7,
                  child: Material(
                    color: Colors.transparent,
                    child: _buildTagChip(
                      tag: tag,
                      bgColor: bgColor,
                      textColor: textColor,
                      onRemove: () {},
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _buildTagChip(
                    tag: tag,
                    bgColor: bgColor,
                    textColor: textColor,
                    onRemove: () => onRemoveCurrentTag(tag),
                  ),
                ),
                child: Container(
                  decoration: isHovered
                      ? BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        )
                      : null,
                  child: _buildTagChip(
                    tag: tag,
                    bgColor: bgColor,
                    textColor: textColor,
                    onRemove: () => onRemoveCurrentTag(tag),
                  ),
                ),
              );
            },
          );
        }),
        // Non-reorderable tags to be added (shown in green)
        ...tagsToAdd.map((tag) => _buildTagChip(
          tag: tag,
          bgColor: Colors.green.withValues(alpha: 0.2),
          textColor: Colors.green,
          onRemove: () => onRemoveNewTag(tag),
        )),
      ],
    );
  }

  Widget _buildTagChip({
    required String tag,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onRemove,
  }) {
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
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
