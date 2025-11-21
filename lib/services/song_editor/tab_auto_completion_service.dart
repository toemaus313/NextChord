/// Service for handling tab section auto-completion ({sot}/{eot} tags)
class TabAutoCompletionService {
  /// Check if text change triggers auto-completion and return updated text if needed
  static TabAutoCompletionResult? checkForAutoCompletion(
    String currentText,
    String previousText,
    int cursorPosition,
  ) {
    // Avoid recursive calls during auto-completion
    if (currentText == previousText) {
      return null;
    }

    // Only process if text actually changed and grew
    if (currentText.length <= previousText.length) {
      return null;
    }

    // Check if user just completed typing {sot}
    // We detect this by checking if the text ends with {sot} at the cursor position
    if (cursorPosition >= 5) {
      final beforeCursor = currentText.substring(0, cursorPosition);
      if (beforeCursor.endsWith('{sot}')) {
        // Check if there's already a matching {eot} after this position
        final matchingEotExists = hasMatchingEot(currentText, cursorPosition);

        if (!matchingEotExists) {
          return insertEotAfterSot(currentText, cursorPosition);
        }
      }
    }

    return null;
  }

  /// Check if there's a matching {eot} for the {sot} at the given position
  static bool hasMatchingEot(String text, int sotEndPos) {
    // Look ahead for {eot} within reasonable distance (50 lines)
    final afterSot = text.substring(sotEndPos);
    final lines = afterSot.split('\n');

    // Check up to 50 lines ahead
    final linesToCheck = lines.take(50).join('\n');
    return linesToCheck.toLowerCase().contains('{eot}');
  }

  /// Insert {eot} immediately after {sot} is typed
  /// If tab content already exists, place {eot} at the end of it
  /// Otherwise, insert {eot} with space for typing
  static TabAutoCompletionResult insertEotAfterSot(
      String currentText, int sotEndPos) {
    // Split the text after {sot} into lines
    final before = currentText.substring(0, sotEndPos);
    final after = currentText.substring(sotEndPos);
    final afterLines = after.split('\n');

    // Check if there's tab content in the next few lines
    final tabAnalysisResult = analyzeTabContent(afterLines);

    String newText;
    int newCursorPos;

    if (tabAnalysisResult.hasTab && tabAnalysisResult.tabEndLineIndex >= 0) {
      // Tab content exists - insert {eot} after the last tab line
      final beforeTab = afterLines
          .sublist(0, tabAnalysisResult.tabEndLineIndex + 1)
          .join('\n');
      final afterTab =
          afterLines.sublist(tabAnalysisResult.tabEndLineIndex + 1).join('\n');

      newText = '$before$beforeTab\n{eot}$afterTab';
      // Keep cursor at current position (after {sot})
      newCursorPos = sotEndPos;
    } else {
      // No tab content yet - insert {eot} with space for typing
      newText = '$before\n\n{eot}$after';
      // Position cursor right after {sot} and the newline, ready to type tab
      newCursorPos = sotEndPos + 1;
    }

    return TabAutoCompletionResult(
      updatedText: newText,
      newCursorPosition: newCursorPos,
    );
  }

  /// Analyze lines to detect tab content and find where it ends
  static TabAnalysisResult analyzeTabContent(List<String> lines) {
    bool foundTab = false;
    int tabEndLineIndex = -1;
    int emptyLineCount = 0;

    for (int i = 0; i < lines.length && i < 20; i++) {
      final line = lines[i].trim();

      // Count empty lines before finding first tab
      if (!foundTab && line.isEmpty) {
        emptyLineCount++;
        // If more than 2 empty lines before any tab, give up
        if (emptyLineCount > 2) {
          break;
        }
        continue;
      }

      // Check if this line looks like tab
      if (looksLikeTabLine(line)) {
        if (!foundTab) {
          foundTab = true;
        }
        tabEndLineIndex = i;
        emptyLineCount = 0; // Reset empty line counter
      } else if (foundTab && line.isNotEmpty) {
        // Found non-tab content after tab, stop here
        break;
      } else if (foundTab && line.isEmpty) {
        // Count empty lines within tab block
        emptyLineCount++;
        // If more than 2 empty lines within tab block, stop
        if (emptyLineCount > 2) {
          break;
        }
      }
    }

    return TabAnalysisResult(
      hasTab: foundTab,
      tabEndLineIndex: tabEndLineIndex,
    );
  }

  /// Check if a line looks like guitar tablature
  static bool looksLikeTabLine(String line) {
    if (line.isEmpty) return false;

    // Check for standard guitar string notation (E|, A|, D|, G|, B|, e|)
    final tabLineRegex = RegExp(r'^[EADGBe]\|[\-0-9|]+', caseSensitive: true);
    if (tabLineRegex.hasMatch(line)) return true;

    // Also check for lines that are mostly dashes, numbers, and pipes
    final tabChars = RegExp(r'[\-0-9|]');
    final nonSpaceChars = line.replaceAll(' ', '');
    if (nonSpaceChars.length < 3) return false;

    final tabCharCount = tabChars.allMatches(nonSpaceChars).length;
    return tabCharCount / nonSpaceChars.length > 0.5;
  }

  /// Check if a position is within a tab section
  static bool isWithinTabSection(String text, int position) {
    if (position < 0 || position > text.length) return false;

    final beforePosition = text.substring(0, position);
    final lines = beforePosition.split('\n');

    // Look backwards for {sot} and {eot}
    bool inTabSection = false;

    for (int i = lines.length - 1; i >= 0; i--) {
      final line = lines[i];
      if (line.contains('{eot}')) {
        inTabSection = false;
      } else if (line.contains('{sot}')) {
        inTabSection = true;
        break;
      }
    }

    return inTabSection;
  }

  /// Find the boundaries of the current tab section
  static TabSectionBounds? findTabSectionBounds(String text, int position) {
    if (position < 0 || position > text.length) return null;

    final lines = text.split('\n');
    int currentLineIndex = 0;
    int charCount = 0;

    // Find which line contains the position
    for (int i = 0; i < lines.length; i++) {
      if (charCount + lines[i].length >= position) {
        currentLineIndex = i;
        break;
      }
      charCount += lines[i].length + 1; // +1 for newline
    }

    // Search backwards for {sot}
    int? sotLineIndex;
    for (int i = currentLineIndex; i >= 0; i--) {
      if (lines[i].contains('{sot}')) {
        sotLineIndex = i;
        break;
      }
    }

    // Search forwards for {eot}
    int? eotLineIndex;
    for (int i = sotLineIndex ?? currentLineIndex; i < lines.length; i++) {
      if (lines[i].contains('{eot}')) {
        eotLineIndex = i;
        break;
      }
    }

    if (sotLineIndex != null && eotLineIndex != null) {
      return TabSectionBounds(
        startLineIndex: sotLineIndex,
        endLineIndex: eotLineIndex,
      );
    }

    return null;
  }
}

/// Result of tab auto-completion operation
class TabAutoCompletionResult {
  final String updatedText;
  final int newCursorPosition;

  const TabAutoCompletionResult({
    required this.updatedText,
    required this.newCursorPosition,
  });
}

/// Result of tab content analysis
class TabAnalysisResult {
  final bool hasTab;
  final int tabEndLineIndex;

  const TabAnalysisResult({
    required this.hasTab,
    required this.tabEndLineIndex,
  });
}

/// Boundaries of a tab section
class TabSectionBounds {
  final int startLineIndex;
  final int endLineIndex;

  const TabSectionBounds({
    required this.startLineIndex,
    required this.endLineIndex,
  });
}
