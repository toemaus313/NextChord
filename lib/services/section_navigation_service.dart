import 'package:flutter/material.dart';

/// Service for navigating between sections in a song, including comment tags
class SectionNavigationService {
  final ScrollController scrollController;
  final String chordProContent;

  SectionNavigationService({
    required this.scrollController,
    required this.chordProContent,
  });

  /// Get all section positions including {comment:xxxx} tags and existing markers
  List<SectionMarker> getSectionMarkers() {
    final markers = <SectionMarker>[];
    final lines = chordProContent.split('\n');

    // Always include the top of the song as the first section
    markers.add(SectionMarker(
      lineIndex: 0,
      position: 0.0,
      title: 'Top',
      isComment: false,
    ));

    // Find section markers and comment tags
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Check for existing section markers (you can extend this based on your actual section syntax)
      if (line.startsWith('{section:') || line.startsWith('{marker:')) {
        final title = line
            .substring(9, line.length - 1)
            .trim(); // Remove {section:} or {marker:}
        if (title.isNotEmpty) {
          markers.add(SectionMarker(
            lineIndex: i,
            position: _calculateScrollPosition(i),
            title: title,
            isComment: false,
          ));
        }
      }

      // Check for comment tags to treat as section markers
      if (line.startsWith('{comment:')) {
        final commentText =
            line.substring(9, line.length - 1).trim(); // Remove {comment:}
        if (commentText.isNotEmpty) {
          markers.add(SectionMarker(
            lineIndex: i,
            position: _calculateScrollPosition(i),
            title: commentText,
            isComment: true,
          ));
        }
      }
    }

    // Sort by position and remove duplicates
    markers.sort((a, b) => a.position.compareTo(b.position));

    // Remove markers that are too close to each other (within 50 pixels)
    final uniqueMarkers = <SectionMarker>[];
    for (final marker in markers) {
      if (uniqueMarkers.isEmpty ||
          (marker.position - uniqueMarkers.last.position) > 50.0) {
        uniqueMarkers.add(marker);
      }
    }

    return uniqueMarkers;
  }

  /// Calculate the approximate scroll position for a given line index
  double _calculateScrollPosition(int lineIndex) {
    // This is an approximation - you may need to adjust based on your text rendering
    const lineHeight = 24.0; // Approximate line height in pixels
    const topPadding = 100.0; // Account for header and initial padding

    return topPadding + (lineIndex * lineHeight);
  }

  /// Navigate to the previous section
  Future<bool> navigateToPreviousSection() async {
    if (!scrollController.hasClients) return false;

    final markers = getSectionMarkers();
    final currentPosition = scrollController.offset;

    // Find the current section (the one just before or at current position)
    SectionMarker? currentSection;
    for (int i = markers.length - 1; i >= 0; i--) {
      if (markers[i].position <= currentPosition + 10.0) {
        // 10px tolerance
        currentSection = markers[i];
        break;
      }
    }

    // Find the previous section
    if (currentSection != null) {
      final currentIndex = markers.indexOf(currentSection);
      if (currentIndex > 0) {
        final previousSection = markers[currentIndex - 1];
        await _scrollToSection(previousSection);
        return true;
      }
    } else if (markers.isNotEmpty) {
      // If we couldn't determine current section, go to the first one
      await _scrollToSection(markers.first);
      return true;
    }

    return false;
  }

  /// Navigate to the next section
  Future<bool> navigateToNextSection() async {
    if (!scrollController.hasClients) return false;

    final markers = getSectionMarkers();
    final currentPosition = scrollController.offset;

    // Find the current section (the one just before or at current position)
    SectionMarker? currentSection;
    for (int i = markers.length - 1; i >= 0; i--) {
      if (markers[i].position <= currentPosition + 10.0) {
        // 10px tolerance
        currentSection = markers[i];
        break;
      }
    }

    // Find the next section
    if (currentSection != null) {
      final currentIndex = markers.indexOf(currentSection);
      if (currentIndex < markers.length - 1) {
        final nextSection = markers[currentIndex + 1];
        await _scrollToSection(nextSection);
        return true;
      }
    } else if (markers.isNotEmpty) {
      // If we couldn't determine current section, go to the second one (skip "Top")
      if (markers.length > 1) {
        await _scrollToSection(markers[1]);
        return true;
      }
    }

    return false;
  }

  /// Scroll smoothly to a section marker
  Future<void> _scrollToSection(SectionMarker section) async {
    if (!scrollController.hasClients) return;

    // Ensure we don't scroll past the end
    final maxScroll = scrollController.position.maxScrollExtent;
    final targetPosition = section.position.clamp(0.0, maxScroll);

    await scrollController.animateTo(
      targetPosition,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Check if previous section navigation is available
  bool get hasPreviousSection {
    if (!scrollController.hasClients) return false;

    final markers = getSectionMarkers();
    final currentPosition = scrollController.offset;

    // Find current section
    SectionMarker? currentSection;
    for (int i = markers.length - 1; i >= 0; i--) {
      if (markers[i].position <= currentPosition + 10.0) {
        currentSection = markers[i];
        break;
      }
    }

    if (currentSection != null) {
      final currentIndex = markers.indexOf(currentSection);
      return currentIndex > 0;
    }

    return markers.isNotEmpty;
  }

  /// Check if next section navigation is available
  bool get hasNextSection {
    if (!scrollController.hasClients) return false;

    final markers = getSectionMarkers();
    final currentPosition = scrollController.offset;

    // Find current section
    SectionMarker? currentSection;
    for (int i = markers.length - 1; i >= 0; i--) {
      if (markers[i].position <= currentPosition + 10.0) {
        currentSection = markers[i];
        break;
      }
    }

    if (currentSection != null) {
      final currentIndex = markers.indexOf(currentSection);
      return currentIndex < markers.length - 1;
    }

    return markers.length > 1;
  }
}

/// Represents a section marker in a song
class SectionMarker {
  final int lineIndex;
  final double position;
  final String title;
  final bool isComment;

  SectionMarker({
    required this.lineIndex,
    required this.position,
    required this.title,
    required this.isComment,
  });

  @override
  String toString() {
    return 'SectionMarker(title: "$title", position: $position, isComment: $isComment)';
  }
}
