import 'package:flutter/material.dart';

/// Widget for editing song tags with drag-and-drop reordering
class TagEditor extends StatelessWidget {
  final List<String> tags;
  final Color textColor;
  final bool isDarkMode;
  final ValueChanged<List<String>> onTagsChanged;
  final VoidCallback onEditTags;

  const TagEditor({
    super.key,
    required this.tags,
    required this.textColor,
    required this.isDarkMode,
    required this.onTagsChanged,
    required this.onEditTags,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Tags',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            if (tags.isNotEmpty)
              ...tags.asMap().entries.map((entry) {
                final index = entry.key;
                final tag = entry.value;
                final (bgColor, tagTextColor) = _getTagColors(tag, context);
                return DragTarget<int>(
                  onWillAcceptWithDetails: (details) => details.data != index,
                  onAcceptWithDetails: (details) {
                    final updatedTags = List<String>.from(tags);
                    final tagToMove = updatedTags.removeAt(details.data);
                    updatedTags.insert(index, tagToMove);
                    onTagsChanged(updatedTags);
                  },
                  builder: (context, candidate, rejected) {
                    final isHovered = candidate.isNotEmpty;
                    return Draggable<int>(
                      data: index,
                      feedback: Opacity(
                        opacity: 0.7,
                        child: Material(
                          color: Colors.transparent,
                          child: _TagChip(
                            key: ValueKey('drag_tag_$tag'),
                            tag: tag,
                            bgColor: bgColor,
                            textColor: tagTextColor,
                            onRemove: () {},
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _TagChip(
                          key: ValueKey('tag_drag_${index}_$tag'),
                          tag: tag,
                          bgColor: bgColor,
                          textColor: tagTextColor,
                          onRemove: () {
                            final updatedTags = List<String>.from(tags);
                            updatedTags.removeAt(index);
                            onTagsChanged(updatedTags);
                          },
                        ),
                      ),
                      child: Container(
                        decoration: isHovered
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 1.5,
                                ),
                              )
                            : null,
                        child: _TagChip(
                          key: ValueKey('tag_${index}_$tag'),
                          tag: tag,
                          bgColor: bgColor,
                          textColor: tagTextColor,
                          onRemove: () {
                            final updatedTags = List<String>.from(tags);
                            updatedTags.removeAt(index);
                            onTagsChanged(updatedTags);
                          },
                        ),
                      ),
                    );
                  },
                );
              })
            else
              Text(
                'No tags yet',
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.5),
                ),
              ),
            GestureDetector(
              onTap: onEditTags,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: textColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit,
                      size: 14,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get color for a tag based on whether it's an instrument tag
  (Color, Color) _getTagColors(String tag, BuildContext context) {
    const instrumentTags = {
      'Acoustic',
      'Electric',
      'Piano',
      'Guitar',
      'Bass',
      'Drums',
      'Vocals',
      'Instrumental'
    };

    if (instrumentTags.contains(tag)) {
      return (Colors.orange.withValues(alpha: 0.2), Colors.orange);
    } else {
      return (
        Theme.of(context).colorScheme.primaryContainer,
        Theme.of(context).colorScheme.onPrimaryContainer
      );
    }
  }
}

/// Custom widget for displaying a tag chip with remove button
class _TagChip extends StatelessWidget {
  final String tag;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onRemove;

  const _TagChip({
    super.key,
    required this.tag,
    required this.bgColor,
    required this.textColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
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
