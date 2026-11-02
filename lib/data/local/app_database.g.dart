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

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CachedTendersTable cachedTenders = $CachedTendersTable(this);
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

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CachedTendersTableTableManager get cachedTenders =>
      $$CachedTendersTableTableManager(_db, _db.cachedTenders);
}
