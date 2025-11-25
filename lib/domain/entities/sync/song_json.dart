/// JSON model for song data in library export/import operations
class SongJson {
  final String id;
  final String title;
  final String artist;
  final String body;
  final String key;
  final int capo;
  final String timeSignature;
  final int bpm;
  final String duration;
  final List<String> tags;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;

  SongJson({
    required this.id,
    required this.title,
    required this.artist,
    required this.body,
    required this.key,
    required this.capo,
    required this.timeSignature,
    required this.bpm,
    required this.duration,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'body': body,
        'key': key,
        'capo': capo,
        'timeSignature': timeSignature,
        'bpm': bpm,
        'duration': duration,
        'tags': tags,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'isDeleted': isDeleted,
      };

  factory SongJson.fromJson(Map<String, dynamic> json) => SongJson(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        artist: json['artist'] ?? '',
        body: json['body'] ?? '',
        key: json['key'] ?? '',
        capo: json['capo'] ?? 0,
        timeSignature: json['timeSignature'] ?? '4/4',
        bpm: json['bpm'] ?? 120,
        duration: json['duration'] ?? '',
        tags: List<String>.from(json['tags'] ?? []),
        createdAt: json['createdAt'] ?? '',
        updatedAt: json['updatedAt'] ?? '',
        isDeleted: json['isDeleted'] ?? false,
      );
}
