import '../../domain/entities/midi_profile.dart';

/// Service for parsing MIDI command strings
class MidiCommandParser {
  /// Parse a MIDI command string into a MidiCC object
  ///
  /// Supported formats:
  /// - "PC5" or "PC:5" for Program Change
  /// - "CC7:100" for Control Change
  /// - "timing" for MIDI Clock (handled separately)
  static MidiCC? parseControlChange(String text) {
    final upperText = text.toUpperCase().trim();

    // Parse Program Change: "PC5" or "PC:5"
    if (upperText.startsWith('PC')) {
      final pcMatch = RegExp(r'^PC(\d+)$').firstMatch(upperText) ??
          RegExp(r'^PC:(\d+)$').firstMatch(upperText);
      if (pcMatch != null) {
        final pcValue = int.tryParse(pcMatch.group(1)!);
        if (pcValue != null && pcValue >= 0 && pcValue <= 127) {
          return MidiCC(controller: -1, value: pcValue); // -1 indicates PC
        }
      }
    }

    // Parse Control Change: "CC0:127"
    if (upperText.startsWith('CC')) {
      final ccMatch = RegExp(r'^CC(\d+):(\d+)$').firstMatch(upperText);
      if (ccMatch != null) {
        final controller = int.tryParse(ccMatch.group(1)!);
        final value = int.tryParse(ccMatch.group(2)!);
        if (controller != null &&
            controller >= 0 &&
            controller <= 119 &&
            value != null &&
            value >= 0 &&
            value <= 127) {
          return MidiCC(controller: controller, value: value);
        }
      }
    }

    return null;
  }

  /// Check if the text is a timing command
  static bool isTimingCommand(String text) {
    return text.toUpperCase().trim() == 'TIMING';
  }

  /// Convert a MidiCC to display string
  static String midiCCToString(MidiCC cc) {
    if (cc.controller == -1) {
      return 'PC${cc.value}';
    } else {
      return 'CC${cc.controller}:${cc.value}';
    }
  }

  /// Convert a list of MidiCC objects to display strings with labels
  static List<String> midiCCToDisplayStrings(List<MidiCC> controlChanges) {
    return controlChanges.map((cc) {
      final command = midiCCToString(cc);
      return cc.label != null ? '$command - ${cc.label}' : command;
    }).toList();
  }

  /// Separate program changes and control changes from a mixed list
  static ({int? programChangeNumber, List<MidiCC> controlChanges})
      separateProgramChanges(List<MidiCC> controlChanges) {
    int? programChangeNumber;
    final ccList = <MidiCC>[];

    for (final cc in controlChanges) {
      if (cc.controller == -1) {
        programChangeNumber = cc.value;
      } else {
        ccList.add(cc);
      }
    }

    return (programChangeNumber: programChangeNumber, controlChanges: ccList);
  }

  /// Convert stored profile back to display format (with PC as CC)
  static List<MidiCC> profileToDisplayFormat(MidiProfile profile) {
    final displayChanges = <MidiCC>[];

    // Add program change as CC with controller -1
    if (profile.programChangeNumber != null) {
      displayChanges.add(MidiCC(
        controller: -1, // -1 indicates PC
        value: profile.programChangeNumber!,
      ));
    }

    // Add regular control changes
    displayChanges.addAll(profile.controlChanges);

    return displayChanges;
  }
}
