import 'package:flutter/material.dart';
import '../../domain/entities/song.dart';

/// Widget for displaying song metadata (key, tempo, capo, artist, tags)
class SongMetadataSection extends StatelessWidget {
  final Song song;
  final int currentCapo;
  final String? keyDisplayLabel;
  final List<String> tags;
  final bool hasTags;
  final Color textColor;
  final Future<void> Function(String tag) onRemoveTag;
  final VoidCallback onEditTags;
  final Future<void> Function(List<String>)? onReorderTags;
  final (Color, Color) Function(String tag) getTagColors;

  const SongMetadataSection({
    Key? key,
    required this.song,
    required this.currentCapo,
    this.keyDisplayLabel,
    required this.tags,
    required this.hasTags,
    required this.textColor,
    required this.onRemoveTag,
    required this.onEditTags,
    this.onReorderTags,
    required this.getTagColors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMetadataRow(),
        const SizedBox(height: 16),
        _buildTagsSection(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMetadataRow() {
    final hasBpm = song.bpm > 0;
    final hasTimeSignature = song.timeSignature.isNotEmpty;
    final showCapoBadge = currentCapo > 0;
    final hasArtist = song.artist.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side: Title and Artist
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                ),
              ),
              if (hasArtist) ...[
                const SizedBox(height: 2),
                Text(
                  song.artist,
                  style: TextStyle(
                    fontSize: 14,
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Right side: Key, Tempo, Capo summary text
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (keyDisplayLabel != null)
              Text(
                keyDisplayLabel!,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            if (hasBpm || hasTimeSignature) ...[
              if (keyDisplayLabel != null) const SizedBox(height: 2),
              Text(
                '${hasBpm ? '${song.bpm} bpm' : ''}${hasBpm && hasTimeSignature ? ' ' : ''}${hasTimeSignature ? song.timeSignature : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
            if (showCapoBadge) ...[
              if (keyDisplayLabel != null || hasBpm || hasTimeSignature)
                const SizedBox(height: 2),
              Text(
                'CAPO $currentCapo',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTagsSection() {
    return _ViewerTagWrap(
      tags: tags,
      hasTags: hasTags,
      textColor: textColor,
      onRemove: onRemoveTag,
      onEdit: onEditTags,
      onReorderTags: onReorderTags,
      getTagColors: getTagColors,
    );
  }
}

/// Lightweight tag widget for the song viewer
class _ViewerTagWrap extends StatelessWidget {
  final List<String> tags;
  final bool hasTags;
  final Color textColor;
  final Future<void> Function(String tag) onRemove;
  final VoidCallback onEdit;
  final Future<void> Function(List<String>)? onReorderTags;
  final (Color, Color) Function(String tag) getTagColors;

  const _ViewerTagWrap({
    required this.tags,
    required this.hasTags,
    required this.textColor,
    required this.onRemove,
    required this.onEdit,
    this.onReorderTags,
    required this.getTagColors,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasTags) {
      return Wrap(
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
          Text(
            'No tags yet',
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.6),
            ),
          ),
          _buildEditButton(),
        ],
      );
    }

    return Wrap(
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
        ...tags.asMap().entries.map((entry) {
          final index = entry.key;
          final tag = entry.value;
          final (bgColor, tagTextColor) = getTagColors(tag);
          return DragTarget<int>(
            onWillAcceptWithDetails: (details) => details.data != index,
            onAcceptWithDetails: (details) async {
              final updated = List<String>.from(tags);
              final tagToMove = updated.removeAt(details.data);
              updated.insert(index, tagToMove);
              await _reorderTags(context, updated);
            },
            builder: (context, candidate, rejected) {
              return Draggable<int>(
                data: index,
                feedback: Opacity(
                  opacity: 0.7,
                  child: Material(
                    color: Colors.transparent,
                    child: _TagChip(
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
                    tag: tag,
                    bgColor: bgColor,
                    textColor: tagTextColor,
                    onRemove: () => onRemove(tag),
                  ),
                ),
                child: _TagChip(
                  tag: tag,
                  bgColor: bgColor,
                  textColor: tagTextColor,
                  onRemove: () => onRemove(tag),
                ),
              );
            },
          );
        }),
        _buildEditButton(),
      ],
    );
  }

  Future<void> _reorderTags(BuildContext context, List<String> updated) async {
    if (onReorderTags != null) {
      await onReorderTags!(updated);
    }
  }

  Widget _buildEditButton() {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit, size: 14, color: textColor.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              'Edit',
              style: TextStyle(
                  fontSize: 12, color: textColor.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual tag chip widget
class _TagChip extends StatelessWidget {
  final String tag;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onRemove;

  const _TagChip({
    required this.tag,
    required this.bgColor,
    required this.textColor,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: TextStyle(fontSize: 12, color: textColor),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close, size: 14, color: textColor),
          ),
        ],
      ),
    );
  }
}
