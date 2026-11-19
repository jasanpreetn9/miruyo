// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $KvCacheTable extends KvCache with TableInfo<$KvCacheTable, KvCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KvCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, data, savedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kv_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<KvCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KvCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KvCacheData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $KvCacheTable createAlias(String alias) {
    return $KvCacheTable(attachedDatabase, alias);
  }
}

class KvCacheData extends DataClass implements Insertable<KvCacheData> {
  final String key;
  final String data;
  final DateTime savedAt;
  const KvCacheData({
    required this.key,
    required this.data,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['data'] = Variable<String>(data);
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  KvCacheCompanion toCompanion(bool nullToAbsent) {
    return KvCacheCompanion(
      key: Value(key),
      data: Value(data),
      savedAt: Value(savedAt),
    );
  }

  factory KvCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KvCacheData(
      key: serializer.fromJson<String>(json['key']),
      data: serializer.fromJson<String>(json['data']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'data': serializer.toJson<String>(data),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  KvCacheData copyWith({String? key, String? data, DateTime? savedAt}) =>
      KvCacheData(
        key: key ?? this.key,
        data: data ?? this.data,
        savedAt: savedAt ?? this.savedAt,
      );
  KvCacheData copyWithCompanion(KvCacheCompanion data) {
    return KvCacheData(
      key: data.key.present ? data.key.value : this.key,
      data: data.data.present ? data.data.value : this.data,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KvCacheData(')
          ..write('key: $key, ')
          ..write('data: $data, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, data, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KvCacheData &&
          other.key == this.key &&
          other.data == this.data &&
          other.savedAt == this.savedAt);
}

class KvCacheCompanion extends UpdateCompanion<KvCacheData> {
  final Value<String> key;
  final Value<String> data;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const KvCacheCompanion({
    this.key = const Value.absent(),
    this.data = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KvCacheCompanion.insert({
    required String key,
    required String data,
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       data = Value(data),
       savedAt = Value(savedAt);
  static Insertable<KvCacheData> custom({
    Expression<String>? key,
    Expression<String>? data,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (data != null) 'data': data,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KvCacheCompanion copyWith({
    Value<String>? key,
    Value<String>? data,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return KvCacheCompanion(
      key: key ?? this.key,
      data: data ?? this.data,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KvCacheCompanion(')
          ..write('key: $key, ')
          ..write('data: $data, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingEditsTable extends PendingEdits
    with TableInfo<$PendingEditsTable, PendingEditRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingEditsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _mediaIdMeta = const VerificationMeta(
    'mediaId',
  );
  @override
  late final GeneratedColumn<int> mediaId = GeneratedColumn<int>(
    'media_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  @override
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<int> entryId = GeneratedColumn<int>(
    'entry_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mediaId,
    op,
    payload,
    entryId,
    label,
    createdAt,
    attempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_edits';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingEditRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('media_id')) {
      context.handle(
        _mediaIdMeta,
        mediaId.isAcceptableOrUnknown(data['media_id']!, _mediaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mediaIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingEditRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingEditRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mediaId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}media_id'],
      )!,
      op: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}op'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entry_id'],
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  $PendingEditsTable createAlias(String alias) {
    return $PendingEditsTable(attachedDatabase, alias);
  }
}

class PendingEditRow extends DataClass implements Insertable<PendingEditRow> {
  final int id;
  final int mediaId;

  /// 'save' or 'delete'.
  final String op;

  /// The EntryInput fields, as JSON (saves only).
  final String payload;

  /// The list entry's id (deletes only).
  final int? entryId;

  /// The title, for "Couldn't sync X" messages.
  final String label;
  final DateTime createdAt;
  final int attempts;
  const PendingEditRow({
    required this.id,
    required this.mediaId,
    required this.op,
    required this.payload,
    this.entryId,
    required this.label,
    required this.createdAt,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['media_id'] = Variable<int>(mediaId);
    map['op'] = Variable<String>(op);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || entryId != null) {
      map['entry_id'] = Variable<int>(entryId);
    }
    map['label'] = Variable<String>(label);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  PendingEditsCompanion toCompanion(bool nullToAbsent) {
    return PendingEditsCompanion(
      id: Value(id),
      mediaId: Value(mediaId),
      op: Value(op),
      payload: Value(payload),
      entryId: entryId == null && nullToAbsent
          ? const Value.absent()
          : Value(entryId),
      label: Value(label),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
    );
  }

  factory PendingEditRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingEditRow(
      id: serializer.fromJson<int>(json['id']),
      mediaId: serializer.fromJson<int>(json['mediaId']),
      op: serializer.fromJson<String>(json['op']),
      payload: serializer.fromJson<String>(json['payload']),
      entryId: serializer.fromJson<int?>(json['entryId']),
      label: serializer.fromJson<String>(json['label']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mediaId': serializer.toJson<int>(mediaId),
      'op': serializer.toJson<String>(op),
      'payload': serializer.toJson<String>(payload),
      'entryId': serializer.toJson<int?>(entryId),
      'label': serializer.toJson<String>(label),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  PendingEditRow copyWith({
    int? id,
    int? mediaId,
    String? op,
    String? payload,
    Value<int?> entryId = const Value.absent(),
    String? label,
    DateTime? createdAt,
    int? attempts,
  }) => PendingEditRow(
    id: id ?? this.id,
    mediaId: mediaId ?? this.mediaId,
    op: op ?? this.op,
    payload: payload ?? this.payload,
    entryId: entryId.present ? entryId.value : this.entryId,
    label: label ?? this.label,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
  );
  PendingEditRow copyWithCompanion(PendingEditsCompanion data) {
    return PendingEditRow(
      id: data.id.present ? data.id.value : this.id,
      mediaId: data.mediaId.present ? data.mediaId.value : this.mediaId,
      op: data.op.present ? data.op.value : this.op,
      payload: data.payload.present ? data.payload.value : this.payload,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      label: data.label.present ? data.label.value : this.label,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingEditRow(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('entryId: $entryId, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mediaId,
    op,
    payload,
    entryId,
    label,
    createdAt,
    attempts,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingEditRow &&
          other.id == this.id &&
          other.mediaId == this.mediaId &&
          other.op == this.op &&
          other.payload == this.payload &&
          other.entryId == this.entryId &&
          other.label == this.label &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts);
}

class PendingEditsCompanion extends UpdateCompanion<PendingEditRow> {
  final Value<int> id;
  final Value<int> mediaId;
  final Value<String> op;
  final Value<String> payload;
  final Value<int?> entryId;
  final Value<String> label;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  const PendingEditsCompanion({
    this.id = const Value.absent(),
    this.mediaId = const Value.absent(),
    this.op = const Value.absent(),
    this.payload = const Value.absent(),
    this.entryId = const Value.absent(),
    this.label = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
  });
  PendingEditsCompanion.insert({
    this.id = const Value.absent(),
    required int mediaId,
    required String op,
    this.payload = const Value.absent(),
    this.entryId = const Value.absent(),
    this.label = const Value.absent(),
    required DateTime createdAt,
    this.attempts = const Value.absent(),
  }) : mediaId = Value(mediaId),
       op = Value(op),
       createdAt = Value(createdAt);
  static Insertable<PendingEditRow> custom({
    Expression<int>? id,
    Expression<int>? mediaId,
    Expression<String>? op,
    Expression<String>? payload,
    Expression<int>? entryId,
    Expression<String>? label,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mediaId != null) 'media_id': mediaId,
      if (op != null) 'op': op,
      if (payload != null) 'payload': payload,
      if (entryId != null) 'entry_id': entryId,
      if (label != null) 'label': label,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
    });
  }

  PendingEditsCompanion copyWith({
    Value<int>? id,
    Value<int>? mediaId,
    Value<String>? op,
    Value<String>? payload,
    Value<int?>? entryId,
    Value<String>? label,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
  }) {
    return PendingEditsCompanion(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      op: op ?? this.op,
      payload: payload ?? this.payload,
      entryId: entryId ?? this.entryId,
      label: label ?? this.label,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mediaId.present) {
      map['media_id'] = Variable<int>(mediaId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<int>(entryId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingEditsCompanion(')
          ..write('id: $id, ')
          ..write('mediaId: $mediaId, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('entryId: $entryId, ')
          ..write('label: $label, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $KvCacheTable kvCache = $KvCacheTable(this);
  late final $PendingEditsTable pendingEdits = $PendingEditsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [kvCache, pendingEdits];
}

typedef $$KvCacheTableCreateCompanionBuilder = KvCacheCompanion Function({
  required String key,
  required String data,
  required DateTime savedAt,
  Value<int> rowid,
});
typedef $$KvCacheTableUpdateCompanionBuilder = KvCacheCompanion Function({
  Value<String> key,
  Value<String> data,
  Value<DateTime> savedAt,
  Value<int> rowid,
});

class $$KvCacheTableFilterComposer
    extends Composer<_$AppDatabase, $KvCacheTable> {
  $$KvCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KvCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $KvCacheTable> {
  $$KvCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KvCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $KvCacheTable> {
  $$KvCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$KvCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KvCacheTable,
          KvCacheData,
          $$KvCacheTableFilterComposer,
          $$KvCacheTableOrderingComposer,
          $$KvCacheTableAnnotationComposer,
          $$KvCacheTableCreateCompanionBuilder,
          $$KvCacheTableUpdateCompanionBuilder,
          (
            KvCacheData,
            BaseReferences<_$AppDatabase, $KvCacheTable, KvCacheData>,
          ),
          KvCacheData,
          PrefetchHooks Function()
        > {
  $$KvCacheTableTableManager(_$AppDatabase db, $KvCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KvCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KvCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KvCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KvCacheCompanion(
                key: key,
                data: data,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String data,
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => KvCacheCompanion.insert(
                key: key,
                data: data,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KvCacheTable, KvCacheData>(table),
                  BaseReferences<_$AppDatabase, $KvCacheTable, KvCacheData>(
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

typedef $$KvCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KvCacheTable,
      KvCacheData,
      $$KvCacheTableFilterComposer,
      $$KvCacheTableOrderingComposer,
      $$KvCacheTableAnnotationComposer,
      $$KvCacheTableCreateCompanionBuilder,
      $$KvCacheTableUpdateCompanionBuilder,
      (KvCacheData, BaseReferences<_$AppDatabase, $KvCacheTable, KvCacheData>),
      KvCacheData,
      PrefetchHooks Function()
    >;
typedef $$PendingEditsTableCreateCompanionBuilder =
    PendingEditsCompanion Function({
      Value<int> id,
      required int mediaId,
      required String op,
      Value<String> payload,
      Value<int?> entryId,
      Value<String> label,
      required DateTime createdAt,
      Value<int> attempts,
    });
typedef $$PendingEditsTableUpdateCompanionBuilder =
    PendingEditsCompanion Function({
      Value<int> id,
      Value<int> mediaId,
      Value<String> op,
      Value<String> payload,
      Value<int?> entryId,
      Value<String> label,
      Value<DateTime> createdAt,
      Value<int> attempts,
    });

class $$PendingEditsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingEditsTable> {
  $$PendingEditsTableFilterComposer({
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

  ColumnFilters<int> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingEditsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingEditsTable> {
  $$PendingEditsTableOrderingComposer({
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

  ColumnOrderings<int> get mediaId => $composableBuilder(
    column: $table.mediaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get op => $composableBuilder(
    column: $table.op,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingEditsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingEditsTable> {
  $$PendingEditsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get mediaId =>
      $composableBuilder(column: $table.mediaId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);
}

class $$PendingEditsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingEditsTable,
          PendingEditRow,
          $$PendingEditsTableFilterComposer,
          $$PendingEditsTableOrderingComposer,
          $$PendingEditsTableAnnotationComposer,
          $$PendingEditsTableCreateCompanionBuilder,
          $$PendingEditsTableUpdateCompanionBuilder,
          (
            PendingEditRow,
            BaseReferences<_$AppDatabase, $PendingEditsTable, PendingEditRow>,
          ),
          PendingEditRow,
          PrefetchHooks Function()
        > {
  $$PendingEditsTableTableManager(_$AppDatabase db, $PendingEditsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingEditsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingEditsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingEditsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mediaId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int?> entryId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => PendingEditsCompanion(
                id: id,
                mediaId: mediaId,
                op: op,
                payload: payload,
                entryId: entryId,
                label: label,
                createdAt: createdAt,
                attempts: attempts,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mediaId,
                required String op,
                Value<String> payload = const Value.absent(),
                Value<int?> entryId = const Value.absent(),
                Value<String> label = const Value.absent(),
                required DateTime createdAt,
                Value<int> attempts = const Value.absent(),
              }) => PendingEditsCompanion.insert(
                id: id,
                mediaId: mediaId,
                op: op,
                payload: payload,
                entryId: entryId,
                label: label,
                createdAt: createdAt,
                attempts: attempts,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingEditsTable, PendingEditRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingEditsTable,
                    PendingEditRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingEditsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingEditsTable,
      PendingEditRow,
      $$PendingEditsTableFilterComposer,
      $$PendingEditsTableOrderingComposer,
      $$PendingEditsTableAnnotationComposer,
      $$PendingEditsTableCreateCompanionBuilder,
      $$PendingEditsTableUpdateCompanionBuilder,
      (
        PendingEditRow,
        BaseReferences<_$AppDatabase, $PendingEditsTable, PendingEditRow>,
      ),
      PendingEditRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$KvCacheTableTableManager get kvCache =>
      $$KvCacheTableTableManager(_db, _db.kvCache);
  $$PendingEditsTableTableManager get pendingEdits =>
      $$PendingEditsTableTableManager(_db, _db.pendingEdits);
}
