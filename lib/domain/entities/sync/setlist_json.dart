/// JSON model for setlist data in library export/import operations
class SetlistJson {
  final String id;
  final String name;
  final String description;
  final List<SetlistItemJson> items;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;

  SetlistJson({
    required this.id,
    required this.name,
    required this.description,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'items': items.map((i) => i.toJson()).toList(),
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isDeleted': isDeleted,
      };

  factory SetlistJson.fromJson(Map<String, dynamic> json) => SetlistJson(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        items: (json['items'] as List?)
                ?.map(
                    (i) => SetlistItemJson.fromJson(i as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['createdAt'] ?? '',
        updatedAt: json['updatedAt'] ?? '',
        isDeleted: json['isDeleted'] ?? false,
      );
}

/// JSON model for individual setlist items (songs or dividers)
class SetlistItemJson {
  final String type; // 'song' or 'divider'
  final String? songId;
  final int? transposeSteps;
  final int? capo;
  final String? dividerLabel;
  final String? dividerColor;

  SetlistItemJson({
    required this.type,
    this.songId,
    this.transposeSteps,
    this.capo,
    this.dividerLabel,
    this.dividerColor,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'songId': songId,
        'transposeSteps': transposeSteps,
        'capo': capo,
        'dividerLabel': dividerLabel,
        'dividerColor': dividerColor,
      };

  factory SetlistItemJson.fromJson(Map<String, dynamic> json) =>
      SetlistItemJson(
        type: json['type'] ?? 'song',
        songId: json['songId'],
        transposeSteps: json['transposeSteps'],
        capo: json['capo'],
        dividerLabel: json['dividerLabel'],
        dividerColor: json['dividerColor'],
      );
}
