// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SongsTable extends Songs with TableInfo<$SongsTable, SongModel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('C'));
  static const VerificationMeta _capoMeta = const VerificationMeta('capo');
  @override
  late final GeneratedColumn<int> capo = GeneratedColumn<int>(
      'capo', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<int> bpm = GeneratedColumn<int>(
      'bpm', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(120));
  static const VerificationMeta _timeSignatureMeta =
      const VerificationMeta('timeSignature');
  @override
  late final GeneratedColumn<String> timeSignature = GeneratedColumn<String>(
      'time_signature', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('4/4'));
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _audioFilePathMeta =
      const VerificationMeta('audioFilePath');
  @override
  late final GeneratedColumn<String> audioFilePath = GeneratedColumn<String>(
      'audio_file_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        artist,
        body,
        key,
        capo,
        bpm,
        timeSignature,
        tags,
        audioFilePath,
        notes,
        createdAt,
        updatedAt,
        isDeleted
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(Insertable<SongModel> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    } else if (isInserting) {
      context.missing(_artistMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    }
    if (data.containsKey('capo')) {
      context.handle(
          _capoMeta, capo.isAcceptableOrUnknown(data['capo']!, _capoMeta));
    }
    if (data.containsKey('bpm')) {
      context.handle(
          _bpmMeta, bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta));
    }
    if (data.containsKey('time_signature')) {
      context.handle(
          _timeSignatureMeta,
          timeSignature.isAcceptableOrUnknown(
              data['time_signature']!, _timeSignatureMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('audio_file_path')) {
      context.handle(
          _audioFilePathMeta,
          audioFilePath.isAcceptableOrUnknown(
              data['audio_file_path']!, _audioFilePathMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SongModel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongModel(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      capo: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}capo'])!,
      bpm: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}bpm'])!,
      timeSignature: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}time_signature'])!,
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      audioFilePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}audio_file_path']),
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }
}

class SongModel extends DataClass implements Insertable<SongModel> {
  final String id;
  final String title;
  final String artist;
  final String body;
  final String key;
  final int capo;
  final int bpm;
  final String timeSignature;
  final String tags;
  final String? audioFilePath;
  final String? notes;
  final int createdAt;
  final int updatedAt;
  final bool isDeleted;
  const SongModel(
      {required this.id,
      required this.title,
      required this.artist,
      required this.body,
      required this.key,
      required this.capo,
      required this.bpm,
      required this.timeSignature,
      required this.tags,
      this.audioFilePath,
      this.notes,
      required this.createdAt,
      required this.updatedAt,
      required this.isDeleted});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['artist'] = Variable<String>(artist);
    map['body'] = Variable<String>(body);
    map['key'] = Variable<String>(key);
    map['capo'] = Variable<int>(capo);
    map['bpm'] = Variable<int>(bpm);
    map['time_signature'] = Variable<String>(timeSignature);
    map['tags'] = Variable<String>(tags);
    if (!nullToAbsent || audioFilePath != null) {
      map['audio_file_path'] = Variable<String>(audioFilePath);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      title: Value(title),
      artist: Value(artist),
      body: Value(body),
      key: Value(key),
      capo: Value(capo),
      bpm: Value(bpm),
      timeSignature: Value(timeSignature),
      tags: Value(tags),
      audioFilePath: audioFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioFilePath),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory SongModel.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongModel(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String>(json['artist']),
      body: serializer.fromJson<String>(json['body']),
      key: serializer.fromJson<String>(json['key']),
      capo: serializer.fromJson<int>(json['capo']),
      bpm: serializer.fromJson<int>(json['bpm']),
      timeSignature: serializer.fromJson<String>(json['timeSignature']),
      tags: serializer.fromJson<String>(json['tags']),
      audioFilePath: serializer.fromJson<String?>(json['audioFilePath']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String>(artist),
      'body': serializer.toJson<String>(body),
      'key': serializer.toJson<String>(key),
      'capo': serializer.toJson<int>(capo),
      'bpm': serializer.toJson<int>(bpm),
      'timeSignature': serializer.toJson<String>(timeSignature),
      'tags': serializer.toJson<String>(tags),
      'audioFilePath': serializer.toJson<String?>(audioFilePath),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  SongModel copyWith(
          {String? id,
          String? title,
          String? artist,
          String? body,
          String? key,
          int? capo,
          int? bpm,
          String? timeSignature,
          String? tags,
          Value<String?> audioFilePath = const Value.absent(),
          Value<String?> notes = const Value.absent(),
          int? createdAt,
          int? updatedAt,
          bool? isDeleted}) =>
      SongModel(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist ?? this.artist,
        body: body ?? this.body,
        key: key ?? this.key,
        capo: capo ?? this.capo,
        bpm: bpm ?? this.bpm,
        timeSignature: timeSignature ?? this.timeSignature,
        tags: tags ?? this.tags,
        audioFilePath:
            audioFilePath.present ? audioFilePath.value : this.audioFilePath,
        notes: notes.present ? notes.value : this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDeleted: isDeleted ?? this.isDeleted,
      );
  SongModel copyWithCompanion(SongsCompanion data) {
    return SongModel(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      body: data.body.present ? data.body.value : this.body,
      key: data.key.present ? data.key.value : this.key,
      capo: data.capo.present ? data.capo.value : this.capo,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
      timeSignature: data.timeSignature.present
          ? data.timeSignature.value
          : this.timeSignature,
      tags: data.tags.present ? data.tags.value : this.tags,
      audioFilePath: data.audioFilePath.present
          ? data.audioFilePath.value
          : this.audioFilePath,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongModel(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('body: $body, ')
          ..write('key: $key, ')
          ..write('capo: $capo, ')
          ..write('bpm: $bpm, ')
          ..write('timeSignature: $timeSignature, ')
          ..write('tags: $tags, ')
          ..write('audioFilePath: $audioFilePath, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      title,
      artist,
      body,
      key,
      capo,
      bpm,
      timeSignature,
      tags,
      audioFilePath,
      notes,
      createdAt,
      updatedAt,
      isDeleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongModel &&
          other.id == this.id &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.body == this.body &&
          other.key == this.key &&
          other.capo == this.capo &&
          other.bpm == this.bpm &&
          other.timeSignature == this.timeSignature &&
          other.tags == this.tags &&
          other.audioFilePath == this.audioFilePath &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class SongsCompanion extends UpdateCompanion<SongModel> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> artist;
  final Value<String> body;
  final Value<String> key;
  final Value<int> capo;
  final Value<int> bpm;
  final Value<String> timeSignature;
  final Value<String> tags;
  final Value<String?> audioFilePath;
  final Value<String?> notes;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.body = const Value.absent(),
    this.key = const Value.absent(),
    this.capo = const Value.absent(),
    this.bpm = const Value.absent(),
    this.timeSignature = const Value.absent(),
    this.tags = const Value.absent(),
    this.audioFilePath = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongsCompanion.insert({
    required String id,
    required String title,
    required String artist,
    required String body,
    this.key = const Value.absent(),
    this.capo = const Value.absent(),
    this.bpm = const Value.absent(),
    this.timeSignature = const Value.absent(),
    this.tags = const Value.absent(),
    this.audioFilePath = const Value.absent(),
    this.notes = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        artist = Value(artist),
        body = Value(body),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<SongModel> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? body,
    Expression<String>? key,
    Expression<int>? capo,
    Expression<int>? bpm,
    Expression<String>? timeSignature,
    Expression<String>? tags,
    Expression<String>? audioFilePath,
    Expression<String>? notes,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (body != null) 'body': body,
      if (key != null) 'key': key,
      if (capo != null) 'capo': capo,
      if (bpm != null) 'bpm': bpm,
      if (timeSignature != null) 'time_signature': timeSignature,
      if (tags != null) 'tags': tags,
      if (audioFilePath != null) 'audio_file_path': audioFilePath,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? artist,
      Value<String>? body,
      Value<String>? key,
      Value<int>? capo,
      Value<int>? bpm,
      Value<String>? timeSignature,
      Value<String>? tags,
      Value<String?>? audioFilePath,
      Value<String?>? notes,
      Value<int>? createdAt,
      Value<int>? updatedAt,
      Value<bool>? isDeleted,
      Value<int>? rowid}) {
    return SongsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      body: body ?? this.body,
      key: key ?? this.key,
      capo: capo ?? this.capo,
      bpm: bpm ?? this.bpm,
      timeSignature: timeSignature ?? this.timeSignature,
      tags: tags ?? this.tags,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (capo.present) {
      map['capo'] = Variable<int>(capo.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<int>(bpm.value);
    }
    if (timeSignature.present) {
      map['time_signature'] = Variable<String>(timeSignature.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (audioFilePath.present) {
      map['audio_file_path'] = Variable<String>(audioFilePath.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('body: $body, ')
          ..write('key: $key, ')
          ..write('capo: $capo, ')
          ..write('bpm: $bpm, ')
          ..write('timeSignature: $timeSignature, ')
          ..write('tags: $tags, ')
          ..write('audioFilePath: $audioFilePath, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SetlistsTable extends Setlists
    with TableInfo<$SetlistsTable, SetlistModel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetlistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemsMeta = const VerificationMeta('items');
  @override
  late final GeneratedColumn<String> items = GeneratedColumn<String>(
      'items', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _imagePathMeta =
      const VerificationMeta('imagePath');
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
      'image_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _setlistSpecificEditsEnabledMeta =
      const VerificationMeta('setlistSpecificEditsEnabled');
  @override
  late final GeneratedColumn<bool> setlistSpecificEditsEnabled =
      GeneratedColumn<bool>(
          'setlist_specific_edits_enabled', aliasedName, false,
          type: DriftSqlType.bool,
          requiredDuringInsert: false,
          defaultConstraints: GeneratedColumn.constraintIsAlways(
              'CHECK ("setlist_specific_edits_enabled" IN (0, 1))'),
          defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        items,
        notes,
        imagePath,
        setlistSpecificEditsEnabled,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setlists';
  @override
  VerificationContext validateIntegrity(Insertable<SetlistModel> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('items')) {
      context.handle(
          _itemsMeta, items.isAcceptableOrUnknown(data['items']!, _itemsMeta));
    } else if (isInserting) {
      context.missing(_itemsMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('image_path')) {
      context.handle(_imagePathMeta,
          imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta));
    }
    if (data.containsKey('setlist_specific_edits_enabled')) {
      context.handle(
          _setlistSpecificEditsEnabledMeta,
          setlistSpecificEditsEnabled.isAcceptableOrUnknown(
              data['setlist_specific_edits_enabled']!,
              _setlistSpecificEditsEnabledMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SetlistModel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetlistModel(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      items: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}items'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      imagePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}image_path']),
      setlistSpecificEditsEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.bool,
          data['${effectivePrefix}setlist_specific_edits_enabled'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $SetlistsTable createAlias(String alias) {
    return $SetlistsTable(attachedDatabase, alias);
  }
}

class SetlistModel extends DataClass implements Insertable<SetlistModel> {
  final String id;
  final String name;
  final String items;
  final String? notes;
  final String? imagePath;
  final bool setlistSpecificEditsEnabled;
  final int createdAt;
  final int updatedAt;
  const SetlistModel(
      {required this.id,
      required this.name,
      required this.items,
      this.notes,
      this.imagePath,
      required this.setlistSpecificEditsEnabled,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['items'] = Variable<String>(items);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['setlist_specific_edits_enabled'] =
        Variable<bool>(setlistSpecificEditsEnabled);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SetlistsCompanion toCompanion(bool nullToAbsent) {
    return SetlistsCompanion(
      id: Value(id),
      name: Value(name),
      items: Value(items),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      setlistSpecificEditsEnabled: Value(setlistSpecificEditsEnabled),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SetlistModel.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetlistModel(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      items: serializer.fromJson<String>(json['items']),
      notes: serializer.fromJson<String?>(json['notes']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      setlistSpecificEditsEnabled:
          serializer.fromJson<bool>(json['setlistSpecificEditsEnabled']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'items': serializer.toJson<String>(items),
      'notes': serializer.toJson<String?>(notes),
      'imagePath': serializer.toJson<String?>(imagePath),
      'setlistSpecificEditsEnabled':
          serializer.toJson<bool>(setlistSpecificEditsEnabled),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SetlistModel copyWith(
          {String? id,
          String? name,
          String? items,
          Value<String?> notes = const Value.absent(),
          Value<String?> imagePath = const Value.absent(),
          bool? setlistSpecificEditsEnabled,
          int? createdAt,
          int? updatedAt}) =>
      SetlistModel(
        id: id ?? this.id,
        name: name ?? this.name,
        items: items ?? this.items,
        notes: notes.present ? notes.value : this.notes,
        imagePath: imagePath.present ? imagePath.value : this.imagePath,
        setlistSpecificEditsEnabled:
            setlistSpecificEditsEnabled ?? this.setlistSpecificEditsEnabled,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  SetlistModel copyWithCompanion(SetlistsCompanion data) {
    return SetlistModel(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      items: data.items.present ? data.items.value : this.items,
      notes: data.notes.present ? data.notes.value : this.notes,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      setlistSpecificEditsEnabled: data.setlistSpecificEditsEnabled.present
          ? data.setlistSpecificEditsEnabled.value
          : this.setlistSpecificEditsEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetlistModel(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('items: $items, ')
          ..write('notes: $notes, ')
          ..write('imagePath: $imagePath, ')
          ..write('setlistSpecificEditsEnabled: $setlistSpecificEditsEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, items, notes, imagePath,
      setlistSpecificEditsEnabled, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetlistModel &&
          other.id == this.id &&
          other.name == this.name &&
          other.items == this.items &&
          other.notes == this.notes &&
          other.imagePath == this.imagePath &&
          other.setlistSpecificEditsEnabled ==
              this.setlistSpecificEditsEnabled &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SetlistsCompanion extends UpdateCompanion<SetlistModel> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> items;
  final Value<String?> notes;
  final Value<String?> imagePath;
  final Value<bool> setlistSpecificEditsEnabled;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SetlistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.items = const Value.absent(),
    this.notes = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.setlistSpecificEditsEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetlistsCompanion.insert({
    required String id,
    required String name,
    required String items,
    this.notes = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.setlistSpecificEditsEnabled = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        items = Value(items),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<SetlistModel> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? items,
    Expression<String>? notes,
    Expression<String>? imagePath,
    Expression<bool>? setlistSpecificEditsEnabled,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (items != null) 'items': items,
      if (notes != null) 'notes': notes,
      if (imagePath != null) 'image_path': imagePath,
      if (setlistSpecificEditsEnabled != null)
        'setlist_specific_edits_enabled': setlistSpecificEditsEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetlistsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? items,
      Value<String?>? notes,
      Value<String?>? imagePath,
      Value<bool>? setlistSpecificEditsEnabled,
      Value<int>? createdAt,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return SetlistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      setlistSpecificEditsEnabled:
          setlistSpecificEditsEnabled ?? this.setlistSpecificEditsEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (items.present) {
      map['items'] = Variable<String>(items.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (setlistSpecificEditsEnabled.present) {
      map['setlist_specific_edits_enabled'] =
          Variable<bool>(setlistSpecificEditsEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetlistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('items: $items, ')
          ..write('notes: $notes, ')
          ..write('imagePath: $imagePath, ')
          ..write('setlistSpecificEditsEnabled: $setlistSpecificEditsEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MidiMappingsTable extends MidiMappings
    with TableInfo<$MidiMappingsTable, MidiMappingModel> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MidiMappingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
      'song_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _programChangeNumberMeta =
      const VerificationMeta('programChangeNumber');
  @override
  late final GeneratedColumn<int> programChangeNumber = GeneratedColumn<int>(
      'program_change_number', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _controlChangesMeta =
      const VerificationMeta('controlChanges');
  @override
  late final GeneratedColumn<String> controlChanges = GeneratedColumn<String>(
      'control_changes', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _timingMeta = const VerificationMeta('timing');
  @override
  late final GeneratedColumn<bool> timing = GeneratedColumn<bool>(
      'timing', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("timing" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        songId,
        programChangeNumber,
        controlChanges,
        timing,
        notes,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'midi_mappings';
  @override
  VerificationContext validateIntegrity(Insertable<MidiMappingModel> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta,
          songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('program_change_number')) {
      context.handle(
          _programChangeNumberMeta,
          programChangeNumber.isAcceptableOrUnknown(
              data['program_change_number']!, _programChangeNumberMeta));
    }
    if (data.containsKey('control_changes')) {
      context.handle(
          _controlChangesMeta,
          controlChanges.isAcceptableOrUnknown(
              data['control_changes']!, _controlChangesMeta));
    }
    if (data.containsKey('timing')) {
      context.handle(_timingMeta,
          timing.isAcceptableOrUnknown(data['timing']!, _timingMeta));
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MidiMappingModel map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MidiMappingModel(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      songId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}song_id'])!,
      programChangeNumber: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}program_change_number']),
      controlChanges: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}control_changes'])!,
      timing: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}timing'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $MidiMappingsTable createAlias(String alias) {
    return $MidiMappingsTable(attachedDatabase, alias);
  }
}

class MidiMappingModel extends DataClass
    implements Insertable<MidiMappingModel> {
  final String id;
  final String songId;
  final int? programChangeNumber;
  final String controlChanges;
  final bool timing;
  final String? notes;
  final int createdAt;
  final int updatedAt;
  const MidiMappingModel(
      {required this.id,
      required this.songId,
      this.programChangeNumber,
      required this.controlChanges,
      required this.timing,
      this.notes,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['song_id'] = Variable<String>(songId);
    if (!nullToAbsent || programChangeNumber != null) {
      map['program_change_number'] = Variable<int>(programChangeNumber);
    }
    map['control_changes'] = Variable<String>(controlChanges);
    map['timing'] = Variable<bool>(timing);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  MidiMappingsCompanion toCompanion(bool nullToAbsent) {
    return MidiMappingsCompanion(
      id: Value(id),
      songId: Value(songId),
      programChangeNumber: programChangeNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(programChangeNumber),
      controlChanges: Value(controlChanges),
      timing: Value(timing),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MidiMappingModel.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MidiMappingModel(
      id: serializer.fromJson<String>(json['id']),
      songId: serializer.fromJson<String>(json['songId']),
      programChangeNumber:
          serializer.fromJson<int?>(json['programChangeNumber']),
      controlChanges: serializer.fromJson<String>(json['controlChanges']),
      timing: serializer.fromJson<bool>(json['timing']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'songId': serializer.toJson<String>(songId),
      'programChangeNumber': serializer.toJson<int?>(programChangeNumber),
      'controlChanges': serializer.toJson<String>(controlChanges),
      'timing': serializer.toJson<bool>(timing),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  MidiMappingModel copyWith(
          {String? id,
          String? songId,
          Value<int?> programChangeNumber = const Value.absent(),
          String? controlChanges,
          bool? timing,
          Value<String?> notes = const Value.absent(),
          int? createdAt,
          int? updatedAt}) =>
      MidiMappingModel(
        id: id ?? this.id,
        songId: songId ?? this.songId,
        programChangeNumber: programChangeNumber.present
            ? programChangeNumber.value
            : this.programChangeNumber,
        controlChanges: controlChanges ?? this.controlChanges,
        timing: timing ?? this.timing,
        notes: notes.present ? notes.value : this.notes,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  MidiMappingModel copyWithCompanion(MidiMappingsCompanion data) {
    return MidiMappingModel(
      id: data.id.present ? data.id.value : this.id,
      songId: data.songId.present ? data.songId.value : this.songId,
      programChangeNumber: data.programChangeNumber.present
          ? data.programChangeNumber.value
          : this.programChangeNumber,
      controlChanges: data.controlChanges.present
          ? data.controlChanges.value
          : this.controlChanges,
      timing: data.timing.present ? data.timing.value : this.timing,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MidiMappingModel(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('programChangeNumber: $programChangeNumber, ')
          ..write('controlChanges: $controlChanges, ')
          ..write('timing: $timing, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, songId, programChangeNumber,
      controlChanges, timing, notes, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MidiMappingModel &&
          other.id == this.id &&
          other.songId == this.songId &&
          other.programChangeNumber == this.programChangeNumber &&
          other.controlChanges == this.controlChanges &&
          other.timing == this.timing &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MidiMappingsCompanion extends UpdateCompanion<MidiMappingModel> {
  final Value<String> id;
  final Value<String> songId;
  final Value<int?> programChangeNumber;
  final Value<String> controlChanges;
  final Value<bool> timing;
  final Value<String?> notes;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const MidiMappingsCompanion({
    this.id = const Value.absent(),
    this.songId = const Value.absent(),
    this.programChangeNumber = const Value.absent(),
    this.controlChanges = const Value.absent(),
    this.timing = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MidiMappingsCompanion.insert({
    required String id,
    required String songId,
    this.programChangeNumber = const Value.absent(),
    this.controlChanges = const Value.absent(),
    this.timing = const Value.absent(),
    this.notes = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        songId = Value(songId),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<MidiMappingModel> custom({
    Expression<String>? id,
    Expression<String>? songId,
    Expression<int>? programChangeNumber,
    Expression<String>? controlChanges,
    Expression<bool>? timing,
    Expression<String>? notes,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (songId != null) 'song_id': songId,
      if (programChangeNumber != null)
        'program_change_number': programChangeNumber,
      if (controlChanges != null) 'control_changes': controlChanges,
      if (timing != null) 'timing': timing,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MidiMappingsCompanion copyWith(
      {Value<String>? id,
      Value<String>? songId,
      Value<int?>? programChangeNumber,
      Value<String>? controlChanges,
      Value<bool>? timing,
      Value<String?>? notes,
      Value<int>? createdAt,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return MidiMappingsCompanion(
      id: id ?? this.id,
      songId: songId ?? this.songId,
      programChangeNumber: programChangeNumber ?? this.programChangeNumber,
      controlChanges: controlChanges ?? this.controlChanges,
      timing: timing ?? this.timing,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (programChangeNumber.present) {
      map['program_change_number'] = Variable<int>(programChangeNumber.value);
    }
    if (controlChanges.present) {
      map['control_changes'] = Variable<String>(controlChanges.value);
    }
    if (timing.present) {
      map['timing'] = Variable<bool>(timing.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MidiMappingsCompanion(')
          ..write('id: $id, ')
          ..write('songId: $songId, ')
          ..write('programChangeNumber: $programChangeNumber, ')
          ..write('controlChanges: $controlChanges, ')
          ..write('timing: $timing, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SongsTable songs = $SongsTable(this);
  late final $SetlistsTable setlists = $SetlistsTable(this);
  late final $MidiMappingsTable midiMappings = $MidiMappingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [songs, setlists, midiMappings];
}

typedef $$SongsTableCreateCompanionBuilder = SongsCompanion Function({
  required String id,
  required String title,
  required String artist,
  required String body,
  Value<String> key,
  Value<int> capo,
  Value<int> bpm,
  Value<String> timeSignature,
  Value<String> tags,
  Value<String?> audioFilePath,
  Value<String?> notes,
  required int createdAt,
  required int updatedAt,
  Value<bool> isDeleted,
  Value<int> rowid,
});
typedef $$SongsTableUpdateCompanionBuilder = SongsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> artist,
  Value<String> body,
  Value<String> key,
  Value<int> capo,
  Value<int> bpm,
  Value<String> timeSignature,
  Value<String> tags,
  Value<String?> audioFilePath,
  Value<String?> notes,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<bool> isDeleted,
  Value<int> rowid,
});

class $$SongsTableFilterComposer extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get capo => $composableBuilder(
      column: $table.capo, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bpm => $composableBuilder(
      column: $table.bpm, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timeSignature => $composableBuilder(
      column: $table.timeSignature, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get audioFilePath => $composableBuilder(
      column: $table.audioFilePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnFilters(column));
}

class $$SongsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get capo => $composableBuilder(
      column: $table.capo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bpm => $composableBuilder(
      column: $table.bpm, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timeSignature => $composableBuilder(
      column: $table.timeSignature,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get audioFilePath => $composableBuilder(
      column: $table.audioFilePath,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
      column: $table.isDeleted, builder: (column) => ColumnOrderings(column));
}

class $$SongsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get capo =>
      $composableBuilder(column: $table.capo, builder: (column) => column);

  GeneratedColumn<int> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  GeneratedColumn<String> get timeSignature => $composableBuilder(
      column: $table.timeSignature, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get audioFilePath => $composableBuilder(
      column: $table.audioFilePath, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$SongsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SongsTable,
    SongModel,
    $$SongsTableFilterComposer,
    $$SongsTableOrderingComposer,
    $$SongsTableAnnotationComposer,
    $$SongsTableCreateCompanionBuilder,
    $$SongsTableUpdateCompanionBuilder,
    (SongModel, BaseReferences<_$AppDatabase, $SongsTable, SongModel>),
    SongModel,
    PrefetchHooks Function()> {
  $$SongsTableTableManager(_$AppDatabase db, $SongsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> artist = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String> key = const Value.absent(),
            Value<int> capo = const Value.absent(),
            Value<int> bpm = const Value.absent(),
            Value<String> timeSignature = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<String?> audioFilePath = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SongsCompanion(
            id: id,
            title: title,
            artist: artist,
            body: body,
            key: key,
            capo: capo,
            bpm: bpm,
            timeSignature: timeSignature,
            tags: tags,
            audioFilePath: audioFilePath,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: isDeleted,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String artist,
            required String body,
            Value<String> key = const Value.absent(),
            Value<int> capo = const Value.absent(),
            Value<int> bpm = const Value.absent(),
            Value<String> timeSignature = const Value.absent(),
            Value<String> tags = const Value.absent(),
            Value<String?> audioFilePath = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required int createdAt,
            required int updatedAt,
            Value<bool> isDeleted = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SongsCompanion.insert(
            id: id,
            title: title,
            artist: artist,
            body: body,
            key: key,
            capo: capo,
            bpm: bpm,
            timeSignature: timeSignature,
            tags: tags,
            audioFilePath: audioFilePath,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            isDeleted: isDeleted,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SongsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SongsTable,
    SongModel,
    $$SongsTableFilterComposer,
    $$SongsTableOrderingComposer,
    $$SongsTableAnnotationComposer,
    $$SongsTableCreateCompanionBuilder,
    $$SongsTableUpdateCompanionBuilder,
    (SongModel, BaseReferences<_$AppDatabase, $SongsTable, SongModel>),
    SongModel,
    PrefetchHooks Function()>;
typedef $$SetlistsTableCreateCompanionBuilder = SetlistsCompanion Function({
  required String id,
  required String name,
  required String items,
  Value<String?> notes,
  Value<String?> imagePath,
  Value<bool> setlistSpecificEditsEnabled,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$SetlistsTableUpdateCompanionBuilder = SetlistsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> items,
  Value<String?> notes,
  Value<String?> imagePath,
  Value<bool> setlistSpecificEditsEnabled,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$SetlistsTableFilterComposer
    extends Composer<_$AppDatabase, $SetlistsTable> {
  $$SetlistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get items => $composableBuilder(
      column: $table.items, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get setlistSpecificEditsEnabled => $composableBuilder(
      column: $table.setlistSpecificEditsEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$SetlistsTableOrderingComposer
    extends Composer<_$AppDatabase, $SetlistsTable> {
  $$SetlistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get items => $composableBuilder(
      column: $table.items, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get imagePath => $composableBuilder(
      column: $table.imagePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get setlistSpecificEditsEnabled => $composableBuilder(
      column: $table.setlistSpecificEditsEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$SetlistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetlistsTable> {
  $$SetlistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get items =>
      $composableBuilder(column: $table.items, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<bool> get setlistSpecificEditsEnabled => $composableBuilder(
      column: $table.setlistSpecificEditsEnabled, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SetlistsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SetlistsTable,
    SetlistModel,
    $$SetlistsTableFilterComposer,
    $$SetlistsTableOrderingComposer,
    $$SetlistsTableAnnotationComposer,
    $$SetlistsTableCreateCompanionBuilder,
    $$SetlistsTableUpdateCompanionBuilder,
    (SetlistModel, BaseReferences<_$AppDatabase, $SetlistsTable, SetlistModel>),
    SetlistModel,
    PrefetchHooks Function()> {
  $$SetlistsTableTableManager(_$AppDatabase db, $SetlistsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetlistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetlistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetlistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> items = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<bool> setlistSpecificEditsEnabled = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SetlistsCompanion(
            id: id,
            name: name,
            items: items,
            notes: notes,
            imagePath: imagePath,
            setlistSpecificEditsEnabled: setlistSpecificEditsEnabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String items,
            Value<String?> notes = const Value.absent(),
            Value<String?> imagePath = const Value.absent(),
            Value<bool> setlistSpecificEditsEnabled = const Value.absent(),
            required int createdAt,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              SetlistsCompanion.insert(
            id: id,
            name: name,
            items: items,
            notes: notes,
            imagePath: imagePath,
            setlistSpecificEditsEnabled: setlistSpecificEditsEnabled,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SetlistsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SetlistsTable,
    SetlistModel,
    $$SetlistsTableFilterComposer,
    $$SetlistsTableOrderingComposer,
    $$SetlistsTableAnnotationComposer,
    $$SetlistsTableCreateCompanionBuilder,
    $$SetlistsTableUpdateCompanionBuilder,
    (SetlistModel, BaseReferences<_$AppDatabase, $SetlistsTable, SetlistModel>),
    SetlistModel,
    PrefetchHooks Function()>;
typedef $$MidiMappingsTableCreateCompanionBuilder = MidiMappingsCompanion
    Function({
  required String id,
  required String songId,
  Value<int?> programChangeNumber,
  Value<String> controlChanges,
  Value<bool> timing,
  Value<String?> notes,
  required int createdAt,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$MidiMappingsTableUpdateCompanionBuilder = MidiMappingsCompanion
    Function({
  Value<String> id,
  Value<String> songId,
  Value<int?> programChangeNumber,
  Value<String> controlChanges,
  Value<bool> timing,
  Value<String?> notes,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$MidiMappingsTableFilterComposer
    extends Composer<_$AppDatabase, $MidiMappingsTable> {
  $$MidiMappingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get programChangeNumber => $composableBuilder(
      column: $table.programChangeNumber,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get controlChanges => $composableBuilder(
      column: $table.controlChanges,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get timing => $composableBuilder(
      column: $table.timing, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$MidiMappingsTableOrderingComposer
    extends Composer<_$AppDatabase, $MidiMappingsTable> {
  $$MidiMappingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get programChangeNumber => $composableBuilder(
      column: $table.programChangeNumber,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get controlChanges => $composableBuilder(
      column: $table.controlChanges,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get timing => $composableBuilder(
      column: $table.timing, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$MidiMappingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MidiMappingsTable> {
  $$MidiMappingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<int> get programChangeNumber => $composableBuilder(
      column: $table.programChangeNumber, builder: (column) => column);

  GeneratedColumn<String> get controlChanges => $composableBuilder(
      column: $table.controlChanges, builder: (column) => column);

  GeneratedColumn<bool> get timing =>
      $composableBuilder(column: $table.timing, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MidiMappingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MidiMappingsTable,
    MidiMappingModel,
    $$MidiMappingsTableFilterComposer,
    $$MidiMappingsTableOrderingComposer,
    $$MidiMappingsTableAnnotationComposer,
    $$MidiMappingsTableCreateCompanionBuilder,
    $$MidiMappingsTableUpdateCompanionBuilder,
    (
      MidiMappingModel,
      BaseReferences<_$AppDatabase, $MidiMappingsTable, MidiMappingModel>
    ),
    MidiMappingModel,
    PrefetchHooks Function()> {
  $$MidiMappingsTableTableManager(_$AppDatabase db, $MidiMappingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MidiMappingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MidiMappingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MidiMappingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> songId = const Value.absent(),
            Value<int?> programChangeNumber = const Value.absent(),
            Value<String> controlChanges = const Value.absent(),
            Value<bool> timing = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MidiMappingsCompanion(
            id: id,
            songId: songId,
            programChangeNumber: programChangeNumber,
            controlChanges: controlChanges,
            timing: timing,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String songId,
            Value<int?> programChangeNumber = const Value.absent(),
            Value<String> controlChanges = const Value.absent(),
            Value<bool> timing = const Value.absent(),
            Value<String?> notes = const Value.absent(),
            required int createdAt,
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              MidiMappingsCompanion.insert(
            id: id,
            songId: songId,
            programChangeNumber: programChangeNumber,
            controlChanges: controlChanges,
            timing: timing,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MidiMappingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MidiMappingsTable,
    MidiMappingModel,
    $$MidiMappingsTableFilterComposer,
    $$MidiMappingsTableOrderingComposer,
    $$MidiMappingsTableAnnotationComposer,
    $$MidiMappingsTableCreateCompanionBuilder,
    $$MidiMappingsTableUpdateCompanionBuilder,
    (
      MidiMappingModel,
      BaseReferences<_$AppDatabase, $MidiMappingsTable, MidiMappingModel>
    ),
    MidiMappingModel,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
  $$SetlistsTableTableManager get setlists =>
      $$SetlistsTableTableManager(_db, _db.setlists);
  $$MidiMappingsTableTableManager get midiMappings =>
      $$MidiMappingsTableTableManager(_db, _db.midiMappings);
}

mixin _$SongsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SongsTable get songs => attachedDatabase.songs;
}
mixin _$SetlistsDaoMixin on DatabaseAccessor<AppDatabase> {
  $SetlistsTable get setlists => attachedDatabase.setlists;
}
