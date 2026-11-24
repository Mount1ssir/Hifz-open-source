// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_database.dart';

// ignore_for_file: type=lint
class $MemorizedAyahsTable extends MemorizedAyahs
    with TableInfo<$MemorizedAyahsTable, MemorizedAyah> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemorizedAyahsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _riwayahMeta = const VerificationMeta(
    'riwayah',
  );
  @override
  late final GeneratedColumn<String> riwayah = GeneratedColumn<String>(
    'riwayah',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberingMeta = const VerificationMeta(
    'numbering',
  );
  @override
  late final GeneratedColumn<String> numbering = GeneratedColumn<String>(
    'numbering',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ayahIdMeta = const VerificationMeta('ayahId');
  @override
  late final GeneratedColumn<int> ayahId = GeneratedColumn<int>(
    'ayah_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    riwayah,
    numbering,
    ayahId,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memorized_ayahs';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemorizedAyah> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('riwayah')) {
      context.handle(
        _riwayahMeta,
        riwayah.isAcceptableOrUnknown(data['riwayah']!, _riwayahMeta),
      );
    } else if (isInserting) {
      context.missing(_riwayahMeta);
    }
    if (data.containsKey('numbering')) {
      context.handle(
        _numberingMeta,
        numbering.isAcceptableOrUnknown(data['numbering']!, _numberingMeta),
      );
    } else if (isInserting) {
      context.missing(_numberingMeta);
    }
    if (data.containsKey('ayah_id')) {
      context.handle(
        _ayahIdMeta,
        ayahId.isAcceptableOrUnknown(data['ayah_id']!, _ayahIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ayahIdMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {riwayah, numbering, ayahId};
  @override
  MemorizedAyah map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemorizedAyah(
      riwayah: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}riwayah'],
      )!,
      numbering: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}numbering'],
      )!,
      ayahId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ayah_id'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $MemorizedAyahsTable createAlias(String alias) {
    return $MemorizedAyahsTable(attachedDatabase, alias);
  }
}

class MemorizedAyah extends DataClass implements Insertable<MemorizedAyah> {
  final String riwayah;
  final String numbering;
  final int ayahId;
  final DateTime completedAt;
  const MemorizedAyah({
    required this.riwayah,
    required this.numbering,
    required this.ayahId,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['riwayah'] = Variable<String>(riwayah);
    map['numbering'] = Variable<String>(numbering);
    map['ayah_id'] = Variable<int>(ayahId);
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  MemorizedAyahsCompanion toCompanion(bool nullToAbsent) {
    return MemorizedAyahsCompanion(
      riwayah: Value(riwayah),
      numbering: Value(numbering),
      ayahId: Value(ayahId),
      completedAt: Value(completedAt),
    );
  }

  factory MemorizedAyah.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemorizedAyah(
      riwayah: serializer.fromJson<String>(json['riwayah']),
      numbering: serializer.fromJson<String>(json['numbering']),
      ayahId: serializer.fromJson<int>(json['ayahId']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'riwayah': serializer.toJson<String>(riwayah),
      'numbering': serializer.toJson<String>(numbering),
      'ayahId': serializer.toJson<int>(ayahId),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  MemorizedAyah copyWith({
    String? riwayah,
    String? numbering,
    int? ayahId,
    DateTime? completedAt,
  }) => MemorizedAyah(
    riwayah: riwayah ?? this.riwayah,
    numbering: numbering ?? this.numbering,
    ayahId: ayahId ?? this.ayahId,
    completedAt: completedAt ?? this.completedAt,
  );
  MemorizedAyah copyWithCompanion(MemorizedAyahsCompanion data) {
    return MemorizedAyah(
      riwayah: data.riwayah.present ? data.riwayah.value : this.riwayah,
      numbering: data.numbering.present ? data.numbering.value : this.numbering,
      ayahId: data.ayahId.present ? data.ayahId.value : this.ayahId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemorizedAyah(')
          ..write('riwayah: $riwayah, ')
          ..write('numbering: $numbering, ')
          ..write('ayahId: $ayahId, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(riwayah, numbering, ayahId, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemorizedAyah &&
          other.riwayah == this.riwayah &&
          other.numbering == this.numbering &&
          other.ayahId == this.ayahId &&
          other.completedAt == this.completedAt);
}

class MemorizedAyahsCompanion extends UpdateCompanion<MemorizedAyah> {
  final Value<String> riwayah;
  final Value<String> numbering;
  final Value<int> ayahId;
  final Value<DateTime> completedAt;
  final Value<int> rowid;
  const MemorizedAyahsCompanion({
    this.riwayah = const Value.absent(),
    this.numbering = const Value.absent(),
    this.ayahId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemorizedAyahsCompanion.insert({
    required String riwayah,
    required String numbering,
    required int ayahId,
    required DateTime completedAt,
    this.rowid = const Value.absent(),
  }) : riwayah = Value(riwayah),
       numbering = Value(numbering),
       ayahId = Value(ayahId),
       completedAt = Value(completedAt);
  static Insertable<MemorizedAyah> custom({
    Expression<String>? riwayah,
    Expression<String>? numbering,
    Expression<int>? ayahId,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (riwayah != null) 'riwayah': riwayah,
      if (numbering != null) 'numbering': numbering,
      if (ayahId != null) 'ayah_id': ayahId,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemorizedAyahsCompanion copyWith({
    Value<String>? riwayah,
    Value<String>? numbering,
    Value<int>? ayahId,
    Value<DateTime>? completedAt,
    Value<int>? rowid,
  }) {
    return MemorizedAyahsCompanion(
      riwayah: riwayah ?? this.riwayah,
      numbering: numbering ?? this.numbering,
      ayahId: ayahId ?? this.ayahId,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (riwayah.present) {
      map['riwayah'] = Variable<String>(riwayah.value);
    }
    if (numbering.present) {
      map['numbering'] = Variable<String>(numbering.value);
    }
    if (ayahId.present) {
      map['ayah_id'] = Variable<int>(ayahId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemorizedAyahsCompanion(')
          ..write('riwayah: $riwayah, ')
          ..write('numbering: $numbering, ')
          ..write('ayahId: $ayahId, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PreferencesTable extends Preferences
    with TableInfo<$PreferencesTable, Preference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<Preference> instance, {
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
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Preference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Preference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $PreferencesTable createAlias(String alias) {
    return $PreferencesTable(attachedDatabase, alias);
  }
}

class Preference extends DataClass implements Insertable<Preference> {
  final String key;
  final int value;
  const Preference({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<int>(value);
    return map;
  }

  PreferencesCompanion toCompanion(bool nullToAbsent) {
    return PreferencesCompanion(key: Value(key), value: Value(value));
  }

  factory Preference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Preference(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<int>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<int>(value),
    };
  }

  Preference copyWith({String? key, int? value}) =>
      Preference(key: key ?? this.key, value: value ?? this.value);
  Preference copyWithCompanion(PreferencesCompanion data) {
    return Preference(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Preference(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Preference &&
          other.key == this.key &&
          other.value == this.value);
}

class PreferencesCompanion extends UpdateCompanion<Preference> {
  final Value<String> key;
  final Value<int> value;
  final Value<int> rowid;
  const PreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferencesCompanion.insert({
    required String key,
    required int value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Preference> custom({
    Expression<String>? key,
    Expression<int>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreferencesCompanion copyWith({
    Value<String>? key,
    Value<int>? value,
    Value<int>? rowid,
  }) {
    return PreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewSessionsTable extends ReviewSessions
    with TableInfo<$ReviewSessionsTable, ReviewSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ayahIdsMeta = const VerificationMeta(
    'ayahIds',
  );
  @override
  late final GeneratedColumn<String> ayahIds = GeneratedColumn<String>(
    'ayah_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, ayahIds, startedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ayah_ids')) {
      context.handle(
        _ayahIdsMeta,
        ayahIds.isAcceptableOrUnknown(data['ayah_ids']!, _ayahIdsMeta),
      );
    } else if (isInserting) {
      context.missing(_ayahIdsMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ayahIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ayah_ids'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
    );
  }

  @override
  $ReviewSessionsTable createAlias(String alias) {
    return $ReviewSessionsTable(attachedDatabase, alias);
  }
}

class ReviewSession extends DataClass implements Insertable<ReviewSession> {
  final String id;
  final String ayahIds;
  final DateTime startedAt;
  const ReviewSession({
    required this.id,
    required this.ayahIds,
    required this.startedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ayah_ids'] = Variable<String>(ayahIds);
    map['started_at'] = Variable<DateTime>(startedAt);
    return map;
  }

  ReviewSessionsCompanion toCompanion(bool nullToAbsent) {
    return ReviewSessionsCompanion(
      id: Value(id),
      ayahIds: Value(ayahIds),
      startedAt: Value(startedAt),
    );
  }

  factory ReviewSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewSession(
      id: serializer.fromJson<String>(json['id']),
      ayahIds: serializer.fromJson<String>(json['ayahIds']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ayahIds': serializer.toJson<String>(ayahIds),
      'startedAt': serializer.toJson<DateTime>(startedAt),
    };
  }

  ReviewSession copyWith({String? id, String? ayahIds, DateTime? startedAt}) =>
      ReviewSession(
        id: id ?? this.id,
        ayahIds: ayahIds ?? this.ayahIds,
        startedAt: startedAt ?? this.startedAt,
      );
  ReviewSession copyWithCompanion(ReviewSessionsCompanion data) {
    return ReviewSession(
      id: data.id.present ? data.id.value : this.id,
      ayahIds: data.ayahIds.present ? data.ayahIds.value : this.ayahIds,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewSession(')
          ..write('id: $id, ')
          ..write('ayahIds: $ayahIds, ')
          ..write('startedAt: $startedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, ayahIds, startedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewSession &&
          other.id == this.id &&
          other.ayahIds == this.ayahIds &&
          other.startedAt == this.startedAt);
}

class ReviewSessionsCompanion extends UpdateCompanion<ReviewSession> {
  final Value<String> id;
  final Value<String> ayahIds;
  final Value<DateTime> startedAt;
  final Value<int> rowid;
  const ReviewSessionsCompanion({
    this.id = const Value.absent(),
    this.ayahIds = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewSessionsCompanion.insert({
    required String id,
    required String ayahIds,
    required DateTime startedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ayahIds = Value(ayahIds),
       startedAt = Value(startedAt);
  static Insertable<ReviewSession> custom({
    Expression<String>? id,
    Expression<String>? ayahIds,
    Expression<DateTime>? startedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ayahIds != null) 'ayah_ids': ayahIds,
      if (startedAt != null) 'started_at': startedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? ayahIds,
    Value<DateTime>? startedAt,
    Value<int>? rowid,
  }) {
    return ReviewSessionsCompanion(
      id: id ?? this.id,
      ayahIds: ayahIds ?? this.ayahIds,
      startedAt: startedAt ?? this.startedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ayahIds.present) {
      map['ayah_ids'] = Variable<String>(ayahIds.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewSessionsCompanion(')
          ..write('id: $id, ')
          ..write('ayahIds: $ayahIds, ')
          ..write('startedAt: $startedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReviewAttemptsTable extends ReviewAttempts
    with TableInfo<$ReviewAttemptsTable, ReviewAttempt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewAttemptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES review_sessions (id)',
    ),
  );
  static const VerificationMeta _ordinalMeta = const VerificationMeta(
    'ordinal',
  );
  @override
  late final GeneratedColumn<int> ordinal = GeneratedColumn<int>(
    'ordinal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<int> rating = GeneratedColumn<int>(
    'rating',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sessionId,
    ordinal,
    rating,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_attempts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReviewAttempt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('ordinal')) {
      context.handle(
        _ordinalMeta,
        ordinal.isAcceptableOrUnknown(data['ordinal']!, _ordinalMeta),
      );
    } else if (isInserting) {
      context.missing(_ordinalMeta);
    }
    if (data.containsKey('rating')) {
      context.handle(
        _ratingMeta,
        rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta),
      );
    } else if (isInserting) {
      context.missing(_ratingMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sessionId, ordinal};
  @override
  ReviewAttempt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewAttempt(
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      ordinal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ordinal'],
      )!,
      rating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rating'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $ReviewAttemptsTable createAlias(String alias) {
    return $ReviewAttemptsTable(attachedDatabase, alias);
  }
}

class ReviewAttempt extends DataClass implements Insertable<ReviewAttempt> {
  final String sessionId;
  final int ordinal;
  final int rating;
  final DateTime completedAt;
  const ReviewAttempt({
    required this.sessionId,
    required this.ordinal,
    required this.rating,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['session_id'] = Variable<String>(sessionId);
    map['ordinal'] = Variable<int>(ordinal);
    map['rating'] = Variable<int>(rating);
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  ReviewAttemptsCompanion toCompanion(bool nullToAbsent) {
    return ReviewAttemptsCompanion(
      sessionId: Value(sessionId),
      ordinal: Value(ordinal),
      rating: Value(rating),
      completedAt: Value(completedAt),
    );
  }

  factory ReviewAttempt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewAttempt(
      sessionId: serializer.fromJson<String>(json['sessionId']),
      ordinal: serializer.fromJson<int>(json['ordinal']),
      rating: serializer.fromJson<int>(json['rating']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sessionId': serializer.toJson<String>(sessionId),
      'ordinal': serializer.toJson<int>(ordinal),
      'rating': serializer.toJson<int>(rating),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  ReviewAttempt copyWith({
    String? sessionId,
    int? ordinal,
    int? rating,
    DateTime? completedAt,
  }) => ReviewAttempt(
    sessionId: sessionId ?? this.sessionId,
    ordinal: ordinal ?? this.ordinal,
    rating: rating ?? this.rating,
    completedAt: completedAt ?? this.completedAt,
  );
  ReviewAttempt copyWithCompanion(ReviewAttemptsCompanion data) {
    return ReviewAttempt(
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      ordinal: data.ordinal.present ? data.ordinal.value : this.ordinal,
      rating: data.rating.present ? data.rating.value : this.rating,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewAttempt(')
          ..write('sessionId: $sessionId, ')
          ..write('ordinal: $ordinal, ')
          ..write('rating: $rating, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(sessionId, ordinal, rating, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewAttempt &&
          other.sessionId == this.sessionId &&
          other.ordinal == this.ordinal &&
          other.rating == this.rating &&
          other.completedAt == this.completedAt);
}

class ReviewAttemptsCompanion extends UpdateCompanion<ReviewAttempt> {
  final Value<String> sessionId;
  final Value<int> ordinal;
  final Value<int> rating;
  final Value<DateTime> completedAt;
  final Value<int> rowid;
  const ReviewAttemptsCompanion({
    this.sessionId = const Value.absent(),
    this.ordinal = const Value.absent(),
    this.rating = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReviewAttemptsCompanion.insert({
    required String sessionId,
    required int ordinal,
    required int rating,
    required DateTime completedAt,
    this.rowid = const Value.absent(),
  }) : sessionId = Value(sessionId),
       ordinal = Value(ordinal),
       rating = Value(rating),
       completedAt = Value(completedAt);
  static Insertable<ReviewAttempt> custom({
    Expression<String>? sessionId,
    Expression<int>? ordinal,
    Expression<int>? rating,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sessionId != null) 'session_id': sessionId,
      if (ordinal != null) 'ordinal': ordinal,
      if (rating != null) 'rating': rating,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReviewAttemptsCompanion copyWith({
    Value<String>? sessionId,
    Value<int>? ordinal,
    Value<int>? rating,
    Value<DateTime>? completedAt,
    Value<int>? rowid,
  }) {
    return ReviewAttemptsCompanion(
      sessionId: sessionId ?? this.sessionId,
      ordinal: ordinal ?? this.ordinal,
      rating: rating ?? this.rating,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (ordinal.present) {
      map['ordinal'] = Variable<int>(ordinal.value);
    }
    if (rating.present) {
      map['rating'] = Variable<int>(rating.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewAttemptsCompanion(')
          ..write('sessionId: $sessionId, ')
          ..write('ordinal: $ordinal, ')
          ..write('rating: $rating, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$UserDatabase extends GeneratedDatabase {
  _$UserDatabase(QueryExecutor e) : super(e);
  $UserDatabaseManager get managers => $UserDatabaseManager(this);
  late final $MemorizedAyahsTable memorizedAyahs = $MemorizedAyahsTable(this);
  late final $PreferencesTable preferences = $PreferencesTable(this);
  late final $ReviewSessionsTable reviewSessions = $ReviewSessionsTable(this);
  late final $ReviewAttemptsTable reviewAttempts = $ReviewAttemptsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    memorizedAyahs,
    preferences,
    reviewSessions,
    reviewAttempts,
  ];
}

typedef $$MemorizedAyahsTableCreateCompanionBuilder =
    MemorizedAyahsCompanion Function({
      required String riwayah,
      required String numbering,
      required int ayahId,
      required DateTime completedAt,
      Value<int> rowid,
    });
typedef $$MemorizedAyahsTableUpdateCompanionBuilder =
    MemorizedAyahsCompanion Function({
      Value<String> riwayah,
      Value<String> numbering,
      Value<int> ayahId,
      Value<DateTime> completedAt,
      Value<int> rowid,
    });

class $$MemorizedAyahsTableFilterComposer
    extends Composer<_$UserDatabase, $MemorizedAyahsTable> {
  $$MemorizedAyahsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get riwayah => $composableBuilder(
    column: $table.riwayah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get numbering => $composableBuilder(
    column: $table.numbering,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ayahId => $composableBuilder(
    column: $table.ayahId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemorizedAyahsTableOrderingComposer
    extends Composer<_$UserDatabase, $MemorizedAyahsTable> {
  $$MemorizedAyahsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get riwayah => $composableBuilder(
    column: $table.riwayah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get numbering => $composableBuilder(
    column: $table.numbering,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ayahId => $composableBuilder(
    column: $table.ayahId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemorizedAyahsTableAnnotationComposer
    extends Composer<_$UserDatabase, $MemorizedAyahsTable> {
  $$MemorizedAyahsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get riwayah =>
      $composableBuilder(column: $table.riwayah, builder: (column) => column);

  GeneratedColumn<String> get numbering =>
      $composableBuilder(column: $table.numbering, builder: (column) => column);

  GeneratedColumn<int> get ayahId =>
      $composableBuilder(column: $table.ayahId, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$MemorizedAyahsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $MemorizedAyahsTable,
          MemorizedAyah,
          $$MemorizedAyahsTableFilterComposer,
          $$MemorizedAyahsTableOrderingComposer,
          $$MemorizedAyahsTableAnnotationComposer,
          $$MemorizedAyahsTableCreateCompanionBuilder,
          $$MemorizedAyahsTableUpdateCompanionBuilder,
          (
            MemorizedAyah,
            BaseReferences<_$UserDatabase, $MemorizedAyahsTable, MemorizedAyah>,
          ),
          MemorizedAyah,
          PrefetchHooks Function()
        > {
  $$MemorizedAyahsTableTableManager(
    _$UserDatabase db,
    $MemorizedAyahsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemorizedAyahsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemorizedAyahsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemorizedAyahsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> riwayah = const Value.absent(),
                Value<String> numbering = const Value.absent(),
                Value<int> ayahId = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemorizedAyahsCompanion(
                riwayah: riwayah,
                numbering: numbering,
                ayahId: ayahId,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String riwayah,
                required String numbering,
                required int ayahId,
                required DateTime completedAt,
                Value<int> rowid = const Value.absent(),
              }) => MemorizedAyahsCompanion.insert(
                riwayah: riwayah,
                numbering: numbering,
                ayahId: ayahId,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MemorizedAyahsTable, MemorizedAyah>(table),
                  BaseReferences<
                    _$UserDatabase,
                    $MemorizedAyahsTable,
                    MemorizedAyah
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemorizedAyahsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $MemorizedAyahsTable,
      MemorizedAyah,
      $$MemorizedAyahsTableFilterComposer,
      $$MemorizedAyahsTableOrderingComposer,
      $$MemorizedAyahsTableAnnotationComposer,
      $$MemorizedAyahsTableCreateCompanionBuilder,
      $$MemorizedAyahsTableUpdateCompanionBuilder,
      (
        MemorizedAyah,
        BaseReferences<_$UserDatabase, $MemorizedAyahsTable, MemorizedAyah>,
      ),
      MemorizedAyah,
      PrefetchHooks Function()
    >;
typedef $$PreferencesTableCreateCompanionBuilder =
    PreferencesCompanion Function({
      required String key,
      required int value,
      Value<int> rowid,
    });
typedef $$PreferencesTableUpdateCompanionBuilder =
    PreferencesCompanion Function({
      Value<String> key,
      Value<int> value,
      Value<int> rowid,
    });

class $$PreferencesTableFilterComposer
    extends Composer<_$UserDatabase, $PreferencesTable> {
  $$PreferencesTableFilterComposer({
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

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferencesTableOrderingComposer
    extends Composer<_$UserDatabase, $PreferencesTable> {
  $$PreferencesTableOrderingComposer({
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

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferencesTableAnnotationComposer
    extends Composer<_$UserDatabase, $PreferencesTable> {
  $$PreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$PreferencesTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $PreferencesTable,
          Preference,
          $$PreferencesTableFilterComposer,
          $$PreferencesTableOrderingComposer,
          $$PreferencesTableAnnotationComposer,
          $$PreferencesTableCreateCompanionBuilder,
          $$PreferencesTableUpdateCompanionBuilder,
          (
            Preference,
            BaseReferences<_$UserDatabase, $PreferencesTable, Preference>,
          ),
          Preference,
          PrefetchHooks Function()
        > {
  $$PreferencesTableTableManager(_$UserDatabase db, $PreferencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<int> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PreferencesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required int value,
                Value<int> rowid = const Value.absent(),
              }) => PreferencesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PreferencesTable, Preference>(table),
                  BaseReferences<_$UserDatabase, $PreferencesTable, Preference>(
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

typedef $$PreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $PreferencesTable,
      Preference,
      $$PreferencesTableFilterComposer,
      $$PreferencesTableOrderingComposer,
      $$PreferencesTableAnnotationComposer,
      $$PreferencesTableCreateCompanionBuilder,
      $$PreferencesTableUpdateCompanionBuilder,
      (
        Preference,
        BaseReferences<_$UserDatabase, $PreferencesTable, Preference>,
      ),
      Preference,
      PrefetchHooks Function()
    >;
typedef $$ReviewSessionsTableCreateCompanionBuilder =
    ReviewSessionsCompanion Function({
      required String id,
      required String ayahIds,
      required DateTime startedAt,
      Value<int> rowid,
    });
typedef $$ReviewSessionsTableUpdateCompanionBuilder =
    ReviewSessionsCompanion Function({
      Value<String> id,
      Value<String> ayahIds,
      Value<DateTime> startedAt,
      Value<int> rowid,
    });

final class $$ReviewSessionsTableReferences
    extends
        BaseReferences<_$UserDatabase, $ReviewSessionsTable, ReviewSession> {
  $$ReviewSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ReviewAttemptsTable, List<ReviewAttempt>>
  _reviewAttemptsRefsTable(_$UserDatabase db) => MultiTypedResultKey.fromTable(
    db.reviewAttempts,
    aliasName: 'review_sessions__id__review_attempts__session_id',
  );

  $$ReviewAttemptsTableProcessedTableManager get reviewAttemptsRefs {
    final manager = $$ReviewAttemptsTableTableManager(
      $_db,
      $_db.reviewAttempts,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_reviewAttemptsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ReviewSessionsTableFilterComposer
    extends Composer<_$UserDatabase, $ReviewSessionsTable> {
  $$ReviewSessionsTableFilterComposer({
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

  ColumnFilters<String> get ayahIds => $composableBuilder(
    column: $table.ayahIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> reviewAttemptsRefs(
    Expression<bool> Function($$ReviewAttemptsTableFilterComposer f) f,
  ) {
    final $$ReviewAttemptsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewAttempts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewAttemptsTableFilterComposer(
            $db: $db,
            $table: $db.reviewAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReviewSessionsTableOrderingComposer
    extends Composer<_$UserDatabase, $ReviewSessionsTable> {
  $$ReviewSessionsTableOrderingComposer({
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

  ColumnOrderings<String> get ayahIds => $composableBuilder(
    column: $table.ayahIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReviewSessionsTableAnnotationComposer
    extends Composer<_$UserDatabase, $ReviewSessionsTable> {
  $$ReviewSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get ayahIds =>
      $composableBuilder(column: $table.ayahIds, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  Expression<T> reviewAttemptsRefs<T extends Object>(
    Expression<T> Function($$ReviewAttemptsTableAnnotationComposer a) f,
  ) {
    final $$ReviewAttemptsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reviewAttempts,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewAttemptsTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewAttempts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ReviewSessionsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $ReviewSessionsTable,
          ReviewSession,
          $$ReviewSessionsTableFilterComposer,
          $$ReviewSessionsTableOrderingComposer,
          $$ReviewSessionsTableAnnotationComposer,
          $$ReviewSessionsTableCreateCompanionBuilder,
          $$ReviewSessionsTableUpdateCompanionBuilder,
          (ReviewSession, $$ReviewSessionsTableReferences),
          ReviewSession,
          PrefetchHooks Function({bool reviewAttemptsRefs})
        > {
  $$ReviewSessionsTableTableManager(
    _$UserDatabase db,
    $ReviewSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ayahIds = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewSessionsCompanion(
                id: id,
                ayahIds: ayahIds,
                startedAt: startedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ayahIds,
                required DateTime startedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReviewSessionsCompanion.insert(
                id: id,
                ayahIds: ayahIds,
                startedAt: startedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewSessionsTable, ReviewSession>(table),
                  $$ReviewSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({reviewAttemptsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (reviewAttemptsRefs) db.reviewAttempts,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (reviewAttemptsRefs)
                    await $_getPrefetchedDataByColumns<
                      ReviewSession,
                      $ReviewSessionsTable,
                      ReviewAttempt,
                      $ReviewAttemptsTable
                    >(
                      currentTable: table,
                      referencedTable: $$ReviewSessionsTableReferences
                          ._reviewAttemptsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ReviewSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).reviewAttemptsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'session_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ReviewSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $ReviewSessionsTable,
      ReviewSession,
      $$ReviewSessionsTableFilterComposer,
      $$ReviewSessionsTableOrderingComposer,
      $$ReviewSessionsTableAnnotationComposer,
      $$ReviewSessionsTableCreateCompanionBuilder,
      $$ReviewSessionsTableUpdateCompanionBuilder,
      (ReviewSession, $$ReviewSessionsTableReferences),
      ReviewSession,
      PrefetchHooks Function({bool reviewAttemptsRefs})
    >;
typedef $$ReviewAttemptsTableCreateCompanionBuilder =
    ReviewAttemptsCompanion Function({
      required String sessionId,
      required int ordinal,
      required int rating,
      required DateTime completedAt,
      Value<int> rowid,
    });
typedef $$ReviewAttemptsTableUpdateCompanionBuilder =
    ReviewAttemptsCompanion Function({
      Value<String> sessionId,
      Value<int> ordinal,
      Value<int> rating,
      Value<DateTime> completedAt,
      Value<int> rowid,
    });

final class $$ReviewAttemptsTableReferences
    extends
        BaseReferences<_$UserDatabase, $ReviewAttemptsTable, ReviewAttempt> {
  $$ReviewAttemptsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ReviewSessionsTable _sessionIdTable(_$UserDatabase db) => db
      .reviewSessions
      .createAlias('review_attempts__session_id__review_sessions__id');

  $$ReviewSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$ReviewSessionsTableTableManager(
      $_db,
      $_db.reviewSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReviewAttemptsTableFilterComposer
    extends Composer<_$UserDatabase, $ReviewAttemptsTable> {
  $$ReviewAttemptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ReviewSessionsTableFilterComposer get sessionId {
    final $$ReviewSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.reviewSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewSessionsTableFilterComposer(
            $db: $db,
            $table: $db.reviewSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewAttemptsTableOrderingComposer
    extends Composer<_$UserDatabase, $ReviewAttemptsTable> {
  $$ReviewAttemptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get ordinal => $composableBuilder(
    column: $table.ordinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rating => $composableBuilder(
    column: $table.rating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ReviewSessionsTableOrderingComposer get sessionId {
    final $$ReviewSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.reviewSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.reviewSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewAttemptsTableAnnotationComposer
    extends Composer<_$UserDatabase, $ReviewAttemptsTable> {
  $$ReviewAttemptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get ordinal =>
      $composableBuilder(column: $table.ordinal, builder: (column) => column);

  GeneratedColumn<int> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$ReviewSessionsTableAnnotationComposer get sessionId {
    final $$ReviewSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.reviewSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReviewSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.reviewSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReviewAttemptsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $ReviewAttemptsTable,
          ReviewAttempt,
          $$ReviewAttemptsTableFilterComposer,
          $$ReviewAttemptsTableOrderingComposer,
          $$ReviewAttemptsTableAnnotationComposer,
          $$ReviewAttemptsTableCreateCompanionBuilder,
          $$ReviewAttemptsTableUpdateCompanionBuilder,
          (ReviewAttempt, $$ReviewAttemptsTableReferences),
          ReviewAttempt,
          PrefetchHooks Function({bool sessionId})
        > {
  $$ReviewAttemptsTableTableManager(
    _$UserDatabase db,
    $ReviewAttemptsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewAttemptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewAttemptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewAttemptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sessionId = const Value.absent(),
                Value<int> ordinal = const Value.absent(),
                Value<int> rating = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReviewAttemptsCompanion(
                sessionId: sessionId,
                ordinal: ordinal,
                rating: rating,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sessionId,
                required int ordinal,
                required int rating,
                required DateTime completedAt,
                Value<int> rowid = const Value.absent(),
              }) => ReviewAttemptsCompanion.insert(
                sessionId: sessionId,
                ordinal: ordinal,
                rating: rating,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReviewAttemptsTable, ReviewAttempt>(table),
                  $$ReviewAttemptsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.sessionId,
                        referencedTable: $$ReviewAttemptsTableReferences
                            ._sessionIdTable(db),
                        referencedColumn: $$ReviewAttemptsTableReferences
                            ._sessionIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReviewAttemptsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $ReviewAttemptsTable,
      ReviewAttempt,
      $$ReviewAttemptsTableFilterComposer,
      $$ReviewAttemptsTableOrderingComposer,
      $$ReviewAttemptsTableAnnotationComposer,
      $$ReviewAttemptsTableCreateCompanionBuilder,
      $$ReviewAttemptsTableUpdateCompanionBuilder,
      (ReviewAttempt, $$ReviewAttemptsTableReferences),
      ReviewAttempt,
      PrefetchHooks Function({bool sessionId})
    >;

class $UserDatabaseManager {
  final _$UserDatabase _db;
  $UserDatabaseManager(this._db);
  $$MemorizedAyahsTableTableManager get memorizedAyahs =>
      $$MemorizedAyahsTableTableManager(_db, _db.memorizedAyahs);
  $$PreferencesTableTableManager get preferences =>
      $$PreferencesTableTableManager(_db, _db.preferences);
  $$ReviewSessionsTableTableManager get reviewSessions =>
      $$ReviewSessionsTableTableManager(_db, _db.reviewSessions);
  $$ReviewAttemptsTableTableManager get reviewAttempts =>
      $$ReviewAttemptsTableTableManager(_db, _db.reviewAttempts);
}
