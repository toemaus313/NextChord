/// Summary of merge operations during library sync
class MergeDeltaSummary {
  final int songsAdded;
  final int songsUpdated;
  final int songsDeleted;
  final int setlistsAdded;
  final int setlistsUpdated;
  final int setlistsDeleted;
  final int conflictsResolved;
  final List<String> conflictDetails;
  final DateTime mergeTimestamp;

  MergeDeltaSummary({
    required this.songsAdded,
    required this.songsUpdated,
    required this.songsDeleted,
    required this.setlistsAdded,
    required this.setlistsUpdated,
    required this.setlistsDeleted,
    required this.conflictsResolved,
    required this.conflictDetails,
    required this.mergeTimestamp,
  });

  /// Get total number of changes made
  int get totalChanges =>
      songsAdded +
      songsUpdated +
      songsDeleted +
      setlistsAdded +
      setlistsUpdated +
      setlistsDeleted;

  /// Check if any changes were made
  bool get hasChanges => totalChanges > 0 || conflictsResolved > 0;

  /// Get human-readable summary
  String get summary {
    final parts = <String>[];

    if (songsAdded > 0) parts.add('$songsAdded songs added');
    if (songsUpdated > 0) parts.add('$songsUpdated songs updated');
    if (songsDeleted > 0) parts.add('$songsDeleted songs deleted');
    if (setlistsAdded > 0) parts.add('$setlistsAdded setlists added');
    if (setlistsUpdated > 0) parts.add('$setlistsUpdated setlists updated');
    if (setlistsDeleted > 0) parts.add('$setlistsDeleted setlists deleted');
    if (conflictsResolved > 0)
      parts.add('$conflictsResolved conflicts resolved');

    return parts.isEmpty ? 'No changes' : parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
        'songsAdded': songsAdded,
        'songsUpdated': songsUpdated,
        'songsDeleted': songsDeleted,
        'setlistsAdded': setlistsAdded,
        'setlistsUpdated': setlistsUpdated,
        'setlistsDeleted': setlistsDeleted,
        'conflictsResolved': conflictsResolved,
        'conflictDetails': conflictDetails,
        'mergeTimestamp': mergeTimestamp.toIso8601String(),
      };

  factory MergeDeltaSummary.fromJson(Map<String, dynamic> json) =>
      MergeDeltaSummary(
        songsAdded: json['songsAdded'] ?? 0,
        songsUpdated: json['songsUpdated'] ?? 0,
        songsDeleted: json['songsDeleted'] ?? 0,
        setlistsAdded: json['setlistsAdded'] ?? 0,
        setlistsUpdated: json['setlistsUpdated'] ?? 0,
        setlistsDeleted: json['setlistsDeleted'] ?? 0,
        conflictsResolved: json['conflictsResolved'] ?? 0,
        conflictDetails: List<String>.from(json['conflictDetails'] ?? []),
        mergeTimestamp: DateTime.parse(
            json['mergeTimestamp'] ?? DateTime.now().toIso8601String()),
      );
}
