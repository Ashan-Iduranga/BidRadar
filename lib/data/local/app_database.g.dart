// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CachedTendersTable extends CachedTenders
    with TableInfo<$CachedTendersTable, CachedTender> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTendersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textHashMeta = const VerificationMeta(
    'textHash',
  );
  @override
  late final GeneratedColumn<String> textHash = GeneratedColumn<String>(
    'text_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deadlineMeta = const VerificationMeta(
    'deadline',
  );
  @override
  late final GeneratedColumn<DateTime> deadline = GeneratedColumn<DateTime>(
    'deadline',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    sourceId,
    textHash,
    deadline,
    fetchedAt,
    json,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_tenders';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedTender> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceIdMeta);
    }
    if (data.containsKey('text_hash')) {
      context.handle(
        _textHashMeta,
        textHash.isAcceptableOrUnknown(data['text_hash']!, _textHashMeta),
      );
    } else if (isInserting) {
      context.missing(_textHashMeta);
    }
    if (data.containsKey('deadline')) {
      context.handle(
        _deadlineMeta,
        deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CachedTender map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTender(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      )!,
      textHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_hash'],
      )!,
      deadline: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deadline'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $CachedTendersTable createAlias(String alias) {
    return $CachedTendersTable(attachedDatabase, alias);
  }
}

class CachedTender extends DataClass implements Insertable<CachedTender> {
  /// `source_sourceId`, same as the Firestore document ID.
  final String id;
  final String source;
  final String sourceId;
  final String textHash;
  final DateTime? deadline;
  final DateTime fetchedAt;
  final String json;
  const CachedTender({
    required this.id,
    required this.source,
    required this.sourceId,
    required this.textHash,
    this.deadline,
    required this.fetchedAt,
    required this.json,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source'] = Variable<String>(source);
    map['source_id'] = Variable<String>(sourceId);
    map['text_hash'] = Variable<String>(textHash);
    if (!nullToAbsent || deadline != null) {
      map['deadline'] = Variable<DateTime>(deadline);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    map['json'] = Variable<String>(json);
    return map;
  }

  CachedTendersCompanion toCompanion(bool nullToAbsent) {
    return CachedTendersCompanion(
      id: Value(id),
      source: Value(source),
      sourceId: Value(sourceId),
      textHash: Value(textHash),
      deadline: deadline == null && nullToAbsent
          ? const Value.absent()
          : Value(deadline),
      fetchedAt: Value(fetchedAt),
      json: Value(json),
    );
  }

  factory CachedTender.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTender(
      id: serializer.fromJson<String>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      sourceId: serializer.fromJson<String>(json['sourceId']),
      textHash: serializer.fromJson<String>(json['textHash']),
      deadline: serializer.fromJson<DateTime?>(json['deadline']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'source': serializer.toJson<String>(source),
      'sourceId': serializer.toJson<String>(sourceId),
      'textHash': serializer.toJson<String>(textHash),
      'deadline': serializer.toJson<DateTime?>(deadline),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
      'json': serializer.toJson<String>(json),
    };
  }

  CachedTender copyWith({
    String? id,
    String? source,
    String? sourceId,
    String? textHash,
    Value<DateTime?> deadline = const Value.absent(),
    DateTime? fetchedAt,
    String? json,
  }) => CachedTender(
    id: id ?? this.id,
    source: source ?? this.source,
    sourceId: sourceId ?? this.sourceId,
    textHash: textHash ?? this.textHash,
    deadline: deadline.present ? deadline.value : this.deadline,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    json: json ?? this.json,
  );
  CachedTender copyWithCompanion(CachedTendersCompanion data) {
    return CachedTender(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      textHash: data.textHash.present ? data.textHash.value : this.textHash,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTender(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('textHash: $textHash, ')
          ..write('deadline: $deadline, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, source, sourceId, textHash, deadline, fetchedAt, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTender &&
          other.id == this.id &&
          other.source == this.source &&
          other.sourceId == this.sourceId &&
          other.textHash == this.textHash &&
          other.deadline == this.deadline &&
          other.fetchedAt == this.fetchedAt &&
          other.json == this.json);
}

class CachedTendersCompanion extends UpdateCompanion<CachedTender> {
  final Value<String> id;
  final Value<String> source;
  final Value<String> sourceId;
  final Value<String> textHash;
  final Value<DateTime?> deadline;
  final Value<DateTime> fetchedAt;
  final Value<String> json;
  final Value<int> rowid;
  const CachedTendersCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.textHash = const Value.absent(),
    this.deadline = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedTendersCompanion.insert({
    required String id,
    required String source,
    required String sourceId,
    required String textHash,
    this.deadline = const Value.absent(),
    required DateTime fetchedAt,
    required String json,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       source = Value(source),
       sourceId = Value(sourceId),
       textHash = Value(textHash),
       fetchedAt = Value(fetchedAt),
       json = Value(json);
  static Insertable<CachedTender> custom({
    Expression<String>? id,
    Expression<String>? source,
    Expression<String>? sourceId,
    Expression<String>? textHash,
    Expression<DateTime>? deadline,
    Expression<DateTime>? fetchedAt,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (sourceId != null) 'source_id': sourceId,
      if (textHash != null) 'text_hash': textHash,
      if (deadline != null) 'deadline': deadline,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedTendersCompanion copyWith({
    Value<String>? id,
    Value<String>? source,
    Value<String>? sourceId,
    Value<String>? textHash,
    Value<DateTime?>? deadline,
    Value<DateTime>? fetchedAt,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return CachedTendersCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      textHash: textHash ?? this.textHash,
      deadline: deadline ?? this.deadline,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (textHash.present) {
      map['text_hash'] = Variable<String>(textHash.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<DateTime>(deadline.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedTendersCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('sourceId: $sourceId, ')
          ..write('textHash: $textHash, ')
          ..write('deadline: $deadline, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncRunsTable extends SyncRuns with TableInfo<$SyncRunsTable, SyncRun> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _ranAtMeta = const VerificationMeta('ranAt');
  @override
  late final GeneratedColumn<DateTime> ranAt = GeneratedColumn<DateTime>(
    'ran_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedMeta = const VerificationMeta('added');
  @override
  late final GeneratedColumn<int> added = GeneratedColumn<int>(
    'added',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matchedMeta = const VerificationMeta(
    'matched',
  );
  @override
  late final GeneratedColumn<int> matched = GeneratedColumn<int>(
    'matched',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vetoedMeta = const VerificationMeta('vetoed');
  @override
  late final GeneratedColumn<int> vetoed = GeneratedColumn<int>(
    'vetoed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorsMeta = const VerificationMeta('errors');
  @override
  late final GeneratedColumn<String> errors = GeneratedColumn<String>(
    'errors',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _backgroundMeta = const VerificationMeta(
    'background',
  );
  @override
  late final GeneratedColumn<bool> background = GeneratedColumn<bool>(
    'background',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("background" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ranAt,
    added,
    matched,
    vetoed,
    errors,
    background,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRun> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ran_at')) {
      context.handle(
        _ranAtMeta,
        ranAt.isAcceptableOrUnknown(data['ran_at']!, _ranAtMeta),
      );
    } else if (isInserting) {
      context.missing(_ranAtMeta);
    }
    if (data.containsKey('added')) {
      context.handle(
        _addedMeta,
        added.isAcceptableOrUnknown(data['added']!, _addedMeta),
      );
    } else if (isInserting) {
      context.missing(_addedMeta);
    }
    if (data.containsKey('matched')) {
      context.handle(
        _matchedMeta,
        matched.isAcceptableOrUnknown(data['matched']!, _matchedMeta),
      );
    } else if (isInserting) {
      context.missing(_matchedMeta);
    }
    if (data.containsKey('vetoed')) {
      context.handle(
        _vetoedMeta,
        vetoed.isAcceptableOrUnknown(data['vetoed']!, _vetoedMeta),
      );
    } else if (isInserting) {
      context.missing(_vetoedMeta);
    }
    if (data.containsKey('errors')) {
      context.handle(
        _errorsMeta,
        errors.isAcceptableOrUnknown(data['errors']!, _errorsMeta),
      );
    } else if (isInserting) {
      context.missing(_errorsMeta);
    }
    if (data.containsKey('background')) {
      context.handle(
        _backgroundMeta,
        background.isAcceptableOrUnknown(data['background']!, _backgroundMeta),
      );
    } else if (isInserting) {
      context.missing(_backgroundMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncRun map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRun(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      ranAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ran_at'],
      )!,
      added: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added'],
      )!,
      matched: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}matched'],
      )!,
      vetoed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}vetoed'],
      )!,
      errors: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}errors'],
      )!,
      background: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}background'],
      )!,
    );
  }

  @override
  $SyncRunsTable createAlias(String alias) {
    return $SyncRunsTable(attachedDatabase, alias);
  }
}

class SyncRun extends DataClass implements Insertable<SyncRun> {
  final int id;
  final DateTime ranAt;
  final int added;
  final int matched;
  final int vetoed;

  /// JSON list of error lines.
  final String errors;
  final bool background;
  const SyncRun({
    required this.id,
    required this.ranAt,
    required this.added,
    required this.matched,
    required this.vetoed,
    required this.errors,
    required this.background,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ran_at'] = Variable<DateTime>(ranAt);
    map['added'] = Variable<int>(added);
    map['matched'] = Variable<int>(matched);
    map['vetoed'] = Variable<int>(vetoed);
    map['errors'] = Variable<String>(errors);
    map['background'] = Variable<bool>(background);
    return map;
  }

  SyncRunsCompanion toCompanion(bool nullToAbsent) {
    return SyncRunsCompanion(
      id: Value(id),
      ranAt: Value(ranAt),
      added: Value(added),
      matched: Value(matched),
      vetoed: Value(vetoed),
      errors: Value(errors),
      background: Value(background),
    );
  }

  factory SyncRun.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRun(
      id: serializer.fromJson<int>(json['id']),
      ranAt: serializer.fromJson<DateTime>(json['ranAt']),
      added: serializer.fromJson<int>(json['added']),
      matched: serializer.fromJson<int>(json['matched']),
      vetoed: serializer.fromJson<int>(json['vetoed']),
      errors: serializer.fromJson<String>(json['errors']),
      background: serializer.fromJson<bool>(json['background']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'ranAt': serializer.toJson<DateTime>(ranAt),
      'added': serializer.toJson<int>(added),
      'matched': serializer.toJson<int>(matched),
      'vetoed': serializer.toJson<int>(vetoed),
      'errors': serializer.toJson<String>(errors),
      'background': serializer.toJson<bool>(background),
    };
  }

  SyncRun copyWith({
    int? id,
    DateTime? ranAt,
    int? added,
    int? matched,
    int? vetoed,
    String? errors,
    bool? background,
  }) => SyncRun(
    id: id ?? this.id,
    ranAt: ranAt ?? this.ranAt,
    added: added ?? this.added,
    matched: matched ?? this.matched,
    vetoed: vetoed ?? this.vetoed,
    errors: errors ?? this.errors,
    background: background ?? this.background,
  );
  SyncRun copyWithCompanion(SyncRunsCompanion data) {
    return SyncRun(
      id: data.id.present ? data.id.value : this.id,
      ranAt: data.ranAt.present ? data.ranAt.value : this.ranAt,
      added: data.added.present ? data.added.value : this.added,
      matched: data.matched.present ? data.matched.value : this.matched,
      vetoed: data.vetoed.present ? data.vetoed.value : this.vetoed,
      errors: data.errors.present ? data.errors.value : this.errors,
      background: data.background.present
          ? data.background.value
          : this.background,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRun(')
          ..write('id: $id, ')
          ..write('ranAt: $ranAt, ')
          ..write('added: $added, ')
          ..write('matched: $matched, ')
          ..write('vetoed: $vetoed, ')
          ..write('errors: $errors, ')
          ..write('background: $background')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, ranAt, added, matched, vetoed, errors, background);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRun &&
          other.id == this.id &&
          other.ranAt == this.ranAt &&
          other.added == this.added &&
          other.matched == this.matched &&
          other.vetoed == this.vetoed &&
          other.errors == this.errors &&
          other.background == this.background);
}

class SyncRunsCompanion extends UpdateCompanion<SyncRun> {
  final Value<int> id;
  final Value<DateTime> ranAt;
  final Value<int> added;
  final Value<int> matched;
  final Value<int> vetoed;
  final Value<String> errors;
  final Value<bool> background;
  const SyncRunsCompanion({
    this.id = const Value.absent(),
    this.ranAt = const Value.absent(),
    this.added = const Value.absent(),
    this.matched = const Value.absent(),
    this.vetoed = const Value.absent(),
    this.errors = const Value.absent(),
    this.background = const Value.absent(),
  });
  SyncRunsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime ranAt,
    required int added,
    required int matched,
    required int vetoed,
    required String errors,
    required bool background,
  }) : ranAt = Value(ranAt),
       added = Value(added),
       matched = Value(matched),
       vetoed = Value(vetoed),
       errors = Value(errors),
       background = Value(background);
  static Insertable<SyncRun> custom({
    Expression<int>? id,
    Expression<DateTime>? ranAt,
    Expression<int>? added,
    Expression<int>? matched,
    Expression<int>? vetoed,
    Expression<String>? errors,
    Expression<bool>? background,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ranAt != null) 'ran_at': ranAt,
      if (added != null) 'added': added,
      if (matched != null) 'matched': matched,
      if (vetoed != null) 'vetoed': vetoed,
      if (errors != null) 'errors': errors,
      if (background != null) 'background': background,
    });
  }

  SyncRunsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? ranAt,
    Value<int>? added,
    Value<int>? matched,
    Value<int>? vetoed,
    Value<String>? errors,
    Value<bool>? background,
  }) {
    return SyncRunsCompanion(
      id: id ?? this.id,
      ranAt: ranAt ?? this.ranAt,
      added: added ?? this.added,
      matched: matched ?? this.matched,
      vetoed: vetoed ?? this.vetoed,
      errors: errors ?? this.errors,
      background: background ?? this.background,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (ranAt.present) {
      map['ran_at'] = Variable<DateTime>(ranAt.value);
    }
    if (added.present) {
      map['added'] = Variable<int>(added.value);
    }
    if (matched.present) {
      map['matched'] = Variable<int>(matched.value);
    }
    if (vetoed.present) {
      map['vetoed'] = Variable<int>(vetoed.value);
    }
    if (errors.present) {
      map['errors'] = Variable<String>(errors.value);
    }
    if (background.present) {
      map['background'] = Variable<bool>(background.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRunsCompanion(')
          ..write('id: $id, ')
          ..write('ranAt: $ranAt, ')
          ..write('added: $added, ')
          ..write('matched: $matched, ')
          ..write('vetoed: $vetoed, ')
          ..write('errors: $errors, ')
          ..write('background: $background')
          ..write(')'))
        .toString();
  }
}

class $CachedVerdictsTable extends CachedVerdicts
    with TableInfo<$CachedVerdictsTable, CachedVerdict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedVerdictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _companyIdMeta = const VerificationMeta(
    'companyId',
  );
  @override
  late final GeneratedColumn<String> companyId = GeneratedColumn<String>(
    'company_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tenderIdMeta = const VerificationMeta(
    'tenderId',
  );
  @override
  late final GeneratedColumn<String> tenderId = GeneratedColumn<String>(
    'tender_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _textHashMeta = const VerificationMeta(
    'textHash',
  );
  @override
  late final GeneratedColumn<String> textHash = GeneratedColumn<String>(
    'text_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failuresMeta = const VerificationMeta(
    'failures',
  );
  @override
  late final GeneratedColumn<int> failures = GeneratedColumn<int>(
    'failures',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    companyId,
    tenderId,
    textHash,
    at,
    json,
    failures,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_verdicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedVerdict> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('company_id')) {
      context.handle(
        _companyIdMeta,
        companyId.isAcceptableOrUnknown(data['company_id']!, _companyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_companyIdMeta);
    }
    if (data.containsKey('tender_id')) {
      context.handle(
        _tenderIdMeta,
        tenderId.isAcceptableOrUnknown(data['tender_id']!, _tenderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tenderIdMeta);
    }
    if (data.containsKey('text_hash')) {
      context.handle(
        _textHashMeta,
        textHash.isAcceptableOrUnknown(data['text_hash']!, _textHashMeta),
      );
    } else if (isInserting) {
      context.missing(_textHashMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('failures')) {
      context.handle(
        _failuresMeta,
        failures.isAcceptableOrUnknown(data['failures']!, _failuresMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {companyId, tenderId};
  @override
  CachedVerdict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedVerdict(
      companyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_id'],
      )!,
      tenderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tender_id'],
      )!,
      textHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text_hash'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      failures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failures'],
      )!,
    );
  }

  @override
  $CachedVerdictsTable createAlias(String alias) {
    return $CachedVerdictsTable(attachedDatabase, alias);
  }
}

class CachedVerdict extends DataClass implements Insertable<CachedVerdict> {
  final String companyId;
  final String tenderId;
  final String textHash;
  final DateTime at;
  final String json;

  /// Notice-specific AI failures in a row for this notice text (malformed
  /// or blocked answers). The sync stops retrying the notice after a few.
  final int failures;
  const CachedVerdict({
    required this.companyId,
    required this.tenderId,
    required this.textHash,
    required this.at,
    required this.json,
    required this.failures,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['company_id'] = Variable<String>(companyId);
    map['tender_id'] = Variable<String>(tenderId);
    map['text_hash'] = Variable<String>(textHash);
    map['at'] = Variable<DateTime>(at);
    map['json'] = Variable<String>(json);
    map['failures'] = Variable<int>(failures);
    return map;
  }

  CachedVerdictsCompanion toCompanion(bool nullToAbsent) {
    return CachedVerdictsCompanion(
      companyId: Value(companyId),
      tenderId: Value(tenderId),
      textHash: Value(textHash),
      at: Value(at),
      json: Value(json),
      failures: Value(failures),
    );
  }

  factory CachedVerdict.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedVerdict(
      companyId: serializer.fromJson<String>(json['companyId']),
      tenderId: serializer.fromJson<String>(json['tenderId']),
      textHash: serializer.fromJson<String>(json['textHash']),
      at: serializer.fromJson<DateTime>(json['at']),
      json: serializer.fromJson<String>(json['json']),
      failures: serializer.fromJson<int>(json['failures']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'companyId': serializer.toJson<String>(companyId),
      'tenderId': serializer.toJson<String>(tenderId),
      'textHash': serializer.toJson<String>(textHash),
      'at': serializer.toJson<DateTime>(at),
      'json': serializer.toJson<String>(json),
      'failures': serializer.toJson<int>(failures),
    };
  }

  CachedVerdict copyWith({
    String? companyId,
    String? tenderId,
    String? textHash,
    DateTime? at,
    String? json,
    int? failures,
  }) => CachedVerdict(
    companyId: companyId ?? this.companyId,
    tenderId: tenderId ?? this.tenderId,
    textHash: textHash ?? this.textHash,
    at: at ?? this.at,
    json: json ?? this.json,
    failures: failures ?? this.failures,
  );
  CachedVerdict copyWithCompanion(CachedVerdictsCompanion data) {
    return CachedVerdict(
      companyId: data.companyId.present ? data.companyId.value : this.companyId,
      tenderId: data.tenderId.present ? data.tenderId.value : this.tenderId,
      textHash: data.textHash.present ? data.textHash.value : this.textHash,
      at: data.at.present ? data.at.value : this.at,
      json: data.json.present ? data.json.value : this.json,
      failures: data.failures.present ? data.failures.value : this.failures,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedVerdict(')
          ..write('companyId: $companyId, ')
          ..write('tenderId: $tenderId, ')
          ..write('textHash: $textHash, ')
          ..write('at: $at, ')
          ..write('json: $json, ')
          ..write('failures: $failures')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(companyId, tenderId, textHash, at, json, failures);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedVerdict &&
          other.companyId == this.companyId &&
          other.tenderId == this.tenderId &&
          other.textHash == this.textHash &&
          other.at == this.at &&
          other.json == this.json &&
          other.failures == this.failures);
}

class CachedVerdictsCompanion extends UpdateCompanion<CachedVerdict> {
  final Value<String> companyId;
  final Value<String> tenderId;
  final Value<String> textHash;
  final Value<DateTime> at;
  final Value<String> json;
  final Value<int> failures;
  final Value<int> rowid;
  const CachedVerdictsCompanion({
    this.companyId = const Value.absent(),
    this.tenderId = const Value.absent(),
    this.textHash = const Value.absent(),
    this.at = const Value.absent(),
    this.json = const Value.absent(),
    this.failures = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedVerdictsCompanion.insert({
    required String companyId,
    required String tenderId,
    required String textHash,
    required DateTime at,
    required String json,
    this.failures = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : companyId = Value(companyId),
       tenderId = Value(tenderId),
       textHash = Value(textHash),
       at = Value(at),
       json = Value(json);
  static Insertable<CachedVerdict> custom({
    Expression<String>? companyId,
    Expression<String>? tenderId,
    Expression<String>? textHash,
    Expression<DateTime>? at,
    Expression<String>? json,
    Expression<int>? failures,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (companyId != null) 'company_id': companyId,
      if (tenderId != null) 'tender_id': tenderId,
      if (textHash != null) 'text_hash': textHash,
      if (at != null) 'at': at,
      if (json != null) 'json': json,
      if (failures != null) 'failures': failures,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedVerdictsCompanion copyWith({
    Value<String>? companyId,
    Value<String>? tenderId,
    Value<String>? textHash,
    Value<DateTime>? at,
    Value<String>? json,
    Value<int>? failures,
    Value<int>? rowid,
  }) {
    return CachedVerdictsCompanion(
      companyId: companyId ?? this.companyId,
      tenderId: tenderId ?? this.tenderId,
      textHash: textHash ?? this.textHash,
      at: at ?? this.at,
      json: json ?? this.json,
      failures: failures ?? this.failures,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (companyId.present) {
      map['company_id'] = Variable<String>(companyId.value);
    }
    if (tenderId.present) {
      map['tender_id'] = Variable<String>(tenderId.value);
    }
    if (textHash.present) {
      map['text_hash'] = Variable<String>(textHash.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (failures.present) {
      map['failures'] = Variable<int>(failures.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedVerdictsCompanion(')
          ..write('companyId: $companyId, ')
          ..write('tenderId: $tenderId, ')
          ..write('textHash: $textHash, ')
          ..write('at: $at, ')
          ..write('json: $json, ')
          ..write('failures: $failures, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedTendersTable cachedTenders = $CachedTendersTable(this);
  late final $SyncRunsTable syncRuns = $SyncRunsTable(this);
  late final $CachedVerdictsTable cachedVerdicts = $CachedVerdictsTable(this);
  late final Index idxCachedTendersHash = Index(
    'idx_cached_tenders_hash',
    'CREATE INDEX idx_cached_tenders_hash ON cached_tenders (text_hash)',
  );
  late final Index idxCachedTendersDeadline = Index(
    'idx_cached_tenders_deadline',
    'CREATE INDEX idx_cached_tenders_deadline ON cached_tenders (deadline)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cachedTenders,
    syncRuns,
    cachedVerdicts,
    idxCachedTendersHash,
    idxCachedTendersDeadline,
  ];
}

typedef $$CachedTendersTableCreateCompanionBuilder =
    CachedTendersCompanion Function({
      required String id,
      required String source,
      required String sourceId,
      required String textHash,
      Value<DateTime?> deadline,
      required DateTime fetchedAt,
      required String json,
      Value<int> rowid,
    });
typedef $$CachedTendersTableUpdateCompanionBuilder =
    CachedTendersCompanion Function({
      Value<String> id,
      Value<String> source,
      Value<String> sourceId,
      Value<String> textHash,
      Value<DateTime?> deadline,
      Value<DateTime> fetchedAt,
      Value<String> json,
      Value<int> rowid,
    });

class $$CachedTendersTableFilterComposer
    extends Composer<_$AppDatabase, $CachedTendersTable> {
  $$CachedTendersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textHash => $composableBuilder(
    column: $table.textHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedTendersTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedTendersTable> {
  $$CachedTendersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textHash => $composableBuilder(
    column: $table.textHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedTendersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedTendersTable> {
  $$CachedTendersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get textHash =>
      $composableBuilder(column: $table.textHash, builder: (column) => column);

  GeneratedColumn<DateTime> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$CachedTendersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedTendersTable,
          CachedTender,
          $$CachedTendersTableFilterComposer,
          $$CachedTendersTableOrderingComposer,
          $$CachedTendersTableAnnotationComposer,
          $$CachedTendersTableCreateCompanionBuilder,
          $$CachedTendersTableUpdateCompanionBuilder,
          (
            CachedTender,
            BaseReferences<_$AppDatabase, $CachedTendersTable, CachedTender>,
          ),
          CachedTender,
          PrefetchHooks Function()
        > {
  $$CachedTendersTableTableManager(_$AppDatabase db, $CachedTendersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTendersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedTendersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedTendersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String> sourceId = const Value.absent(),
                Value<String> textHash = const Value.absent(),
                Value<DateTime?> deadline = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedTendersCompanion(
                id: id,
                source: source,
                sourceId: sourceId,
                textHash: textHash,
                deadline: deadline,
                fetchedAt: fetchedAt,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String source,
                required String sourceId,
                required String textHash,
                Value<DateTime?> deadline = const Value.absent(),
                required DateTime fetchedAt,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => CachedTendersCompanion.insert(
                id: id,
                source: source,
                sourceId: sourceId,
                textHash: textHash,
                deadline: deadline,
                fetchedAt: fetchedAt,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedTendersTable, CachedTender>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedTendersTable,
                    CachedTender
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedTendersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedTendersTable,
      CachedTender,
      $$CachedTendersTableFilterComposer,
      $$CachedTendersTableOrderingComposer,
      $$CachedTendersTableAnnotationComposer,
      $$CachedTendersTableCreateCompanionBuilder,
      $$CachedTendersTableUpdateCompanionBuilder,
      (
        CachedTender,
        BaseReferences<_$AppDatabase, $CachedTendersTable, CachedTender>,
      ),
      CachedTender,
      PrefetchHooks Function()
    >;
typedef $$SyncRunsTableCreateCompanionBuilder = SyncRunsCompanion Function({
  Value<int> id,
  required DateTime ranAt,
  required int added,
  required int matched,
  required int vetoed,
  required String errors,
  required bool background,
});
typedef $$SyncRunsTableUpdateCompanionBuilder = SyncRunsCompanion Function({
  Value<int> id,
  Value<DateTime> ranAt,
  Value<int> added,
  Value<int> matched,
  Value<int> vetoed,
  Value<String> errors,
  Value<bool> background,
});

class $$SyncRunsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ranAt => $composableBuilder(
    column: $table.ranAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get matched => $composableBuilder(
    column: $table.matched,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get vetoed => $composableBuilder(
    column: $table.vetoed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errors => $composableBuilder(
    column: $table.errors,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncRunsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ranAt => $composableBuilder(
    column: $table.ranAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get added => $composableBuilder(
    column: $table.added,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get matched => $composableBuilder(
    column: $table.matched,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get vetoed => $composableBuilder(
    column: $table.vetoed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errors => $composableBuilder(
    column: $table.errors,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncRunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncRunsTable> {
  $$SyncRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get ranAt =>
      $composableBuilder(column: $table.ranAt, builder: (column) => column);

  GeneratedColumn<int> get added =>
      $composableBuilder(column: $table.added, builder: (column) => column);

  GeneratedColumn<int> get matched =>
      $composableBuilder(column: $table.matched, builder: (column) => column);

  GeneratedColumn<int> get vetoed =>
      $composableBuilder(column: $table.vetoed, builder: (column) => column);

  GeneratedColumn<String> get errors =>
      $composableBuilder(column: $table.errors, builder: (column) => column);

  GeneratedColumn<bool> get background => $composableBuilder(
    column: $table.background,
    builder: (column) => column,
  );
}

class $$SyncRunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncRunsTable,
          SyncRun,
          $$SyncRunsTableFilterComposer,
          $$SyncRunsTableOrderingComposer,
          $$SyncRunsTableAnnotationComposer,
          $$SyncRunsTableCreateCompanionBuilder,
          $$SyncRunsTableUpdateCompanionBuilder,
          (SyncRun, BaseReferences<_$AppDatabase, $SyncRunsTable, SyncRun>),
          SyncRun,
          PrefetchHooks Function()
        > {
  $$SyncRunsTableTableManager(_$AppDatabase db, $SyncRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> ranAt = const Value.absent(),
                Value<int> added = const Value.absent(),
                Value<int> matched = const Value.absent(),
                Value<int> vetoed = const Value.absent(),
                Value<String> errors = const Value.absent(),
                Value<bool> background = const Value.absent(),
              }) => SyncRunsCompanion(
                id: id,
                ranAt: ranAt,
                added: added,
                matched: matched,
                vetoed: vetoed,
                errors: errors,
                background: background,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime ranAt,
                required int added,
                required int matched,
                required int vetoed,
                required String errors,
                required bool background,
              }) => SyncRunsCompanion.insert(
                id: id,
                ranAt: ranAt,
                added: added,
                matched: matched,
                vetoed: vetoed,
                errors: errors,
                background: background,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncRunsTable, SyncRun>(table),
                  BaseReferences<_$AppDatabase, $SyncRunsTable, SyncRun>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncRunsTable,
      SyncRun,
      $$SyncRunsTableFilterComposer,
      $$SyncRunsTableOrderingComposer,
      $$SyncRunsTableAnnotationComposer,
      $$SyncRunsTableCreateCompanionBuilder,
      $$SyncRunsTableUpdateCompanionBuilder,
      (SyncRun, BaseReferences<_$AppDatabase, $SyncRunsTable, SyncRun>),
      SyncRun,
      PrefetchHooks Function()
    >;
typedef $$CachedVerdictsTableCreateCompanionBuilder =
    CachedVerdictsCompanion Function({
      required String companyId,
      required String tenderId,
      required String textHash,
      required DateTime at,
      required String json,
      Value<int> failures,
      Value<int> rowid,
    });
typedef $$CachedVerdictsTableUpdateCompanionBuilder =
    CachedVerdictsCompanion Function({
      Value<String> companyId,
      Value<String> tenderId,
      Value<String> textHash,
      Value<DateTime> at,
      Value<String> json,
      Value<int> failures,
      Value<int> rowid,
    });

class $$CachedVerdictsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedVerdictsTable> {
  $$CachedVerdictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tenderId => $composableBuilder(
    column: $table.tenderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get textHash => $composableBuilder(
    column: $table.textHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failures => $composableBuilder(
    column: $table.failures,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedVerdictsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedVerdictsTable> {
  $$CachedVerdictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get companyId => $composableBuilder(
    column: $table.companyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tenderId => $composableBuilder(
    column: $table.tenderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get textHash => $composableBuilder(
    column: $table.textHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failures => $composableBuilder(
    column: $table.failures,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedVerdictsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedVerdictsTable> {
  $$CachedVerdictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get companyId =>
      $composableBuilder(column: $table.companyId, builder: (column) => column);

  GeneratedColumn<String> get tenderId =>
      $composableBuilder(column: $table.tenderId, builder: (column) => column);

  GeneratedColumn<String> get textHash =>
      $composableBuilder(column: $table.textHash, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get failures =>
      $composableBuilder(column: $table.failures, builder: (column) => column);
}

class $$CachedVerdictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedVerdictsTable,
          CachedVerdict,
          $$CachedVerdictsTableFilterComposer,
          $$CachedVerdictsTableOrderingComposer,
          $$CachedVerdictsTableAnnotationComposer,
          $$CachedVerdictsTableCreateCompanionBuilder,
          $$CachedVerdictsTableUpdateCompanionBuilder,
          (
            CachedVerdict,
            BaseReferences<_$AppDatabase, $CachedVerdictsTable, CachedVerdict>,
          ),
          CachedVerdict,
          PrefetchHooks Function()
        > {
  $$CachedVerdictsTableTableManager(
    _$AppDatabase db,
    $CachedVerdictsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedVerdictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedVerdictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedVerdictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> companyId = const Value.absent(),
                Value<String> tenderId = const Value.absent(),
                Value<String> textHash = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> failures = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedVerdictsCompanion(
                companyId: companyId,
                tenderId: tenderId,
                textHash: textHash,
                at: at,
                json: json,
                failures: failures,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String companyId,
                required String tenderId,
                required String textHash,
                required DateTime at,
                required String json,
                Value<int> failures = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedVerdictsCompanion.insert(
                companyId: companyId,
                tenderId: tenderId,
                textHash: textHash,
                at: at,
                json: json,
                failures: failures,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedVerdictsTable, CachedVerdict>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedVerdictsTable,
                    CachedVerdict
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedVerdictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedVerdictsTable,
      CachedVerdict,
      $$CachedVerdictsTableFilterComposer,
      $$CachedVerdictsTableOrderingComposer,
      $$CachedVerdictsTableAnnotationComposer,
      $$CachedVerdictsTableCreateCompanionBuilder,
      $$CachedVerdictsTableUpdateCompanionBuilder,
      (
        CachedVerdict,
        BaseReferences<_$AppDatabase, $CachedVerdictsTable, CachedVerdict>,
      ),
      CachedVerdict,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedTendersTableTableManager get cachedTenders =>
      $$CachedTendersTableTableManager(_db, _db.cachedTenders);
  $$SyncRunsTableTableManager get syncRuns =>
      $$SyncRunsTableTableManager(_db, _db.syncRuns);
  $$CachedVerdictsTableTableManager get cachedVerdicts =>
      $$CachedVerdictsTableTableManager(_db, _db.cachedVerdicts);
}
