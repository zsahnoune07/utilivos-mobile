// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CatCategoriesTable extends CatCategories
    with TableInfo<$CatCategoriesTable, CatCategoriesRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, itemsJson, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cat_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatCategoriesRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CatCategoriesRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatCategoriesRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CatCategoriesTable createAlias(String alias) {
    return $CatCategoriesTable(attachedDatabase, alias);
  }
}

class CatCategoriesRow extends DataClass
    implements Insertable<CatCategoriesRow> {
  final int id;
  final String itemsJson;
  final DateTime cachedAt;
  const CatCategoriesRow({
    required this.id,
    required this.itemsJson,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['items_json'] = Variable<String>(itemsJson);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CatCategoriesCompanion toCompanion(bool nullToAbsent) {
    return CatCategoriesCompanion(
      id: Value(id),
      itemsJson: Value(itemsJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory CatCategoriesRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatCategoriesRow(
      id: serializer.fromJson<int>(json['id']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CatCategoriesRow copyWith({int? id, String? itemsJson, DateTime? cachedAt}) =>
      CatCategoriesRow(
        id: id ?? this.id,
        itemsJson: itemsJson ?? this.itemsJson,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  CatCategoriesRow copyWithCompanion(CatCategoriesCompanion data) {
    return CatCategoriesRow(
      id: data.id.present ? data.id.value : this.id,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatCategoriesRow(')
          ..write('id: $id, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemsJson, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatCategoriesRow &&
          other.id == this.id &&
          other.itemsJson == this.itemsJson &&
          other.cachedAt == this.cachedAt);
}

class CatCategoriesCompanion extends UpdateCompanion<CatCategoriesRow> {
  final Value<int> id;
  final Value<String> itemsJson;
  final Value<DateTime> cachedAt;
  const CatCategoriesCompanion({
    this.id = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  CatCategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String itemsJson,
    required DateTime cachedAt,
  }) : itemsJson = Value(itemsJson),
       cachedAt = Value(cachedAt);
  static Insertable<CatCategoriesRow> custom({
    Expression<int>? id,
    Expression<String>? itemsJson,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemsJson != null) 'items_json': itemsJson,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  CatCategoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? itemsJson,
    Value<DateTime>? cachedAt,
  }) {
    return CatCategoriesCompanion(
      id: id ?? this.id,
      itemsJson: itemsJson ?? this.itemsJson,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $CatPluginPagesTable extends CatPluginPages
    with TableInfo<$CatPluginPagesTable, CatPluginPageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatPluginPagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pageKeyMeta = const VerificationMeta(
    'pageKey',
  );
  @override
  late final GeneratedColumn<String> pageKey = GeneratedColumn<String>(
    'page_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextCursorMeta = const VerificationMeta(
    'nextCursor',
  );
  @override
  late final GeneratedColumn<String> nextCursor = GeneratedColumn<String>(
    'next_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    pageKey,
    itemsJson,
    nextCursor,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cat_plugin_pages';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatPluginPageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('page_key')) {
      context.handle(
        _pageKeyMeta,
        pageKey.isAcceptableOrUnknown(data['page_key']!, _pageKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_pageKeyMeta);
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('next_cursor')) {
      context.handle(
        _nextCursorMeta,
        nextCursor.isAcceptableOrUnknown(data['next_cursor']!, _nextCursorMeta),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pageKey};
  @override
  CatPluginPageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatPluginPageRow(
      pageKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}page_key'],
      )!,
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      nextCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}next_cursor'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CatPluginPagesTable createAlias(String alias) {
    return $CatPluginPagesTable(attachedDatabase, alias);
  }
}

class CatPluginPageRow extends DataClass
    implements Insertable<CatPluginPageRow> {
  final String pageKey;
  final String itemsJson;
  final String? nextCursor;
  final DateTime cachedAt;
  const CatPluginPageRow({
    required this.pageKey,
    required this.itemsJson,
    this.nextCursor,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['page_key'] = Variable<String>(pageKey);
    map['items_json'] = Variable<String>(itemsJson);
    if (!nullToAbsent || nextCursor != null) {
      map['next_cursor'] = Variable<String>(nextCursor);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CatPluginPagesCompanion toCompanion(bool nullToAbsent) {
    return CatPluginPagesCompanion(
      pageKey: Value(pageKey),
      itemsJson: Value(itemsJson),
      nextCursor: nextCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(nextCursor),
      cachedAt: Value(cachedAt),
    );
  }

  factory CatPluginPageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatPluginPageRow(
      pageKey: serializer.fromJson<String>(json['pageKey']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      nextCursor: serializer.fromJson<String?>(json['nextCursor']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pageKey': serializer.toJson<String>(pageKey),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'nextCursor': serializer.toJson<String?>(nextCursor),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CatPluginPageRow copyWith({
    String? pageKey,
    String? itemsJson,
    Value<String?> nextCursor = const Value.absent(),
    DateTime? cachedAt,
  }) => CatPluginPageRow(
    pageKey: pageKey ?? this.pageKey,
    itemsJson: itemsJson ?? this.itemsJson,
    nextCursor: nextCursor.present ? nextCursor.value : this.nextCursor,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CatPluginPageRow copyWithCompanion(CatPluginPagesCompanion data) {
    return CatPluginPageRow(
      pageKey: data.pageKey.present ? data.pageKey.value : this.pageKey,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      nextCursor: data.nextCursor.present
          ? data.nextCursor.value
          : this.nextCursor,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatPluginPageRow(')
          ..write('pageKey: $pageKey, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('nextCursor: $nextCursor, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pageKey, itemsJson, nextCursor, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatPluginPageRow &&
          other.pageKey == this.pageKey &&
          other.itemsJson == this.itemsJson &&
          other.nextCursor == this.nextCursor &&
          other.cachedAt == this.cachedAt);
}

class CatPluginPagesCompanion extends UpdateCompanion<CatPluginPageRow> {
  final Value<String> pageKey;
  final Value<String> itemsJson;
  final Value<String?> nextCursor;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CatPluginPagesCompanion({
    this.pageKey = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.nextCursor = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatPluginPagesCompanion.insert({
    required String pageKey,
    required String itemsJson,
    this.nextCursor = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : pageKey = Value(pageKey),
       itemsJson = Value(itemsJson),
       cachedAt = Value(cachedAt);
  static Insertable<CatPluginPageRow> custom({
    Expression<String>? pageKey,
    Expression<String>? itemsJson,
    Expression<String>? nextCursor,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (pageKey != null) 'page_key': pageKey,
      if (itemsJson != null) 'items_json': itemsJson,
      if (nextCursor != null) 'next_cursor': nextCursor,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatPluginPagesCompanion copyWith({
    Value<String>? pageKey,
    Value<String>? itemsJson,
    Value<String?>? nextCursor,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CatPluginPagesCompanion(
      pageKey: pageKey ?? this.pageKey,
      itemsJson: itemsJson ?? this.itemsJson,
      nextCursor: nextCursor ?? this.nextCursor,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pageKey.present) {
      map['page_key'] = Variable<String>(pageKey.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (nextCursor.present) {
      map['next_cursor'] = Variable<String>(nextCursor.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatPluginPagesCompanion(')
          ..write('pageKey: $pageKey, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('nextCursor: $nextCursor, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatPluginDetailsTable extends CatPluginDetails
    with TableInfo<$CatPluginDetailsTable, CatPluginDetailRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatPluginDetailsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slugKeyMeta = const VerificationMeta(
    'slugKey',
  );
  @override
  late final GeneratedColumn<String> slugKey = GeneratedColumn<String>(
    'slug_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pluginJsonMeta = const VerificationMeta(
    'pluginJson',
  );
  @override
  late final GeneratedColumn<String> pluginJson = GeneratedColumn<String>(
    'plugin_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [slugKey, pluginJson, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cat_plugin_details';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatPluginDetailRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slug_key')) {
      context.handle(
        _slugKeyMeta,
        slugKey.isAcceptableOrUnknown(data['slug_key']!, _slugKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_slugKeyMeta);
    }
    if (data.containsKey('plugin_json')) {
      context.handle(
        _pluginJsonMeta,
        pluginJson.isAcceptableOrUnknown(data['plugin_json']!, _pluginJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_pluginJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slugKey};
  @override
  CatPluginDetailRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatPluginDetailRow(
      slugKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug_key'],
      )!,
      pluginJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plugin_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CatPluginDetailsTable createAlias(String alias) {
    return $CatPluginDetailsTable(attachedDatabase, alias);
  }
}

class CatPluginDetailRow extends DataClass
    implements Insertable<CatPluginDetailRow> {
  final String slugKey;
  final String pluginJson;
  final DateTime cachedAt;
  const CatPluginDetailRow({
    required this.slugKey,
    required this.pluginJson,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slug_key'] = Variable<String>(slugKey);
    map['plugin_json'] = Variable<String>(pluginJson);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CatPluginDetailsCompanion toCompanion(bool nullToAbsent) {
    return CatPluginDetailsCompanion(
      slugKey: Value(slugKey),
      pluginJson: Value(pluginJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory CatPluginDetailRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatPluginDetailRow(
      slugKey: serializer.fromJson<String>(json['slugKey']),
      pluginJson: serializer.fromJson<String>(json['pluginJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slugKey': serializer.toJson<String>(slugKey),
      'pluginJson': serializer.toJson<String>(pluginJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CatPluginDetailRow copyWith({
    String? slugKey,
    String? pluginJson,
    DateTime? cachedAt,
  }) => CatPluginDetailRow(
    slugKey: slugKey ?? this.slugKey,
    pluginJson: pluginJson ?? this.pluginJson,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CatPluginDetailRow copyWithCompanion(CatPluginDetailsCompanion data) {
    return CatPluginDetailRow(
      slugKey: data.slugKey.present ? data.slugKey.value : this.slugKey,
      pluginJson: data.pluginJson.present
          ? data.pluginJson.value
          : this.pluginJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatPluginDetailRow(')
          ..write('slugKey: $slugKey, ')
          ..write('pluginJson: $pluginJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slugKey, pluginJson, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatPluginDetailRow &&
          other.slugKey == this.slugKey &&
          other.pluginJson == this.pluginJson &&
          other.cachedAt == this.cachedAt);
}

class CatPluginDetailsCompanion extends UpdateCompanion<CatPluginDetailRow> {
  final Value<String> slugKey;
  final Value<String> pluginJson;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CatPluginDetailsCompanion({
    this.slugKey = const Value.absent(),
    this.pluginJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatPluginDetailsCompanion.insert({
    required String slugKey,
    required String pluginJson,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : slugKey = Value(slugKey),
       pluginJson = Value(pluginJson),
       cachedAt = Value(cachedAt);
  static Insertable<CatPluginDetailRow> custom({
    Expression<String>? slugKey,
    Expression<String>? pluginJson,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (slugKey != null) 'slug_key': slugKey,
      if (pluginJson != null) 'plugin_json': pluginJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatPluginDetailsCompanion copyWith({
    Value<String>? slugKey,
    Value<String>? pluginJson,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CatPluginDetailsCompanion(
      slugKey: slugKey ?? this.slugKey,
      pluginJson: pluginJson ?? this.pluginJson,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slugKey.present) {
      map['slug_key'] = Variable<String>(slugKey.value);
    }
    if (pluginJson.present) {
      map['plugin_json'] = Variable<String>(pluginJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatPluginDetailsCompanion(')
          ..write('slugKey: $slugKey, ')
          ..write('pluginJson: $pluginJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CatPluginVersionsTable extends CatPluginVersions
    with TableInfo<$CatPluginVersionsTable, CatPluginVersionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CatPluginVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _slugKeyMeta = const VerificationMeta(
    'slugKey',
  );
  @override
  late final GeneratedColumn<String> slugKey = GeneratedColumn<String>(
    'slug_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [slugKey, itemsJson, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cat_plugin_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<CatPluginVersionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('slug_key')) {
      context.handle(
        _slugKeyMeta,
        slugKey.isAcceptableOrUnknown(data['slug_key']!, _slugKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_slugKeyMeta);
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {slugKey};
  @override
  CatPluginVersionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CatPluginVersionRow(
      slugKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug_key'],
      )!,
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $CatPluginVersionsTable createAlias(String alias) {
    return $CatPluginVersionsTable(attachedDatabase, alias);
  }
}

class CatPluginVersionRow extends DataClass
    implements Insertable<CatPluginVersionRow> {
  final String slugKey;
  final String itemsJson;
  final DateTime cachedAt;
  const CatPluginVersionRow({
    required this.slugKey,
    required this.itemsJson,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['slug_key'] = Variable<String>(slugKey);
    map['items_json'] = Variable<String>(itemsJson);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  CatPluginVersionsCompanion toCompanion(bool nullToAbsent) {
    return CatPluginVersionsCompanion(
      slugKey: Value(slugKey),
      itemsJson: Value(itemsJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory CatPluginVersionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CatPluginVersionRow(
      slugKey: serializer.fromJson<String>(json['slugKey']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'slugKey': serializer.toJson<String>(slugKey),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  CatPluginVersionRow copyWith({
    String? slugKey,
    String? itemsJson,
    DateTime? cachedAt,
  }) => CatPluginVersionRow(
    slugKey: slugKey ?? this.slugKey,
    itemsJson: itemsJson ?? this.itemsJson,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  CatPluginVersionRow copyWithCompanion(CatPluginVersionsCompanion data) {
    return CatPluginVersionRow(
      slugKey: data.slugKey.present ? data.slugKey.value : this.slugKey,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CatPluginVersionRow(')
          ..write('slugKey: $slugKey, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(slugKey, itemsJson, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CatPluginVersionRow &&
          other.slugKey == this.slugKey &&
          other.itemsJson == this.itemsJson &&
          other.cachedAt == this.cachedAt);
}

class CatPluginVersionsCompanion extends UpdateCompanion<CatPluginVersionRow> {
  final Value<String> slugKey;
  final Value<String> itemsJson;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const CatPluginVersionsCompanion({
    this.slugKey = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CatPluginVersionsCompanion.insert({
    required String slugKey,
    required String itemsJson,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : slugKey = Value(slugKey),
       itemsJson = Value(itemsJson),
       cachedAt = Value(cachedAt);
  static Insertable<CatPluginVersionRow> custom({
    Expression<String>? slugKey,
    Expression<String>? itemsJson,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (slugKey != null) 'slug_key': slugKey,
      if (itemsJson != null) 'items_json': itemsJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CatPluginVersionsCompanion copyWith({
    Value<String>? slugKey,
    Value<String>? itemsJson,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return CatPluginVersionsCompanion(
      slugKey: slugKey ?? this.slugKey,
      itemsJson: itemsJson ?? this.itemsJson,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (slugKey.present) {
      map['slug_key'] = Variable<String>(slugKey.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CatPluginVersionsCompanion(')
          ..write('slugKey: $slugKey, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncKvTable extends SyncKv with TableInfo<$SyncKvTable, SyncKvRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncKvTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rowKeyMeta = const VerificationMeta('rowKey');
  @override
  late final GeneratedColumn<String> rowKey = GeneratedColumn<String>(
    'row_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [rowKey, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_kv';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncKvRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_key')) {
      context.handle(
        _rowKeyMeta,
        rowKey.isAcceptableOrUnknown(data['row_key']!, _rowKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_rowKeyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rowKey};
  @override
  SyncKvRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncKvRow(
      rowKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}row_key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $SyncKvTable createAlias(String alias) {
    return $SyncKvTable(attachedDatabase, alias);
  }
}

class SyncKvRow extends DataClass implements Insertable<SyncKvRow> {
  final String rowKey;
  final String? value;
  const SyncKvRow({required this.rowKey, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['row_key'] = Variable<String>(rowKey);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  SyncKvCompanion toCompanion(bool nullToAbsent) {
    return SyncKvCompanion(
      rowKey: Value(rowKey),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory SyncKvRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncKvRow(
      rowKey: serializer.fromJson<String>(json['rowKey']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rowKey': serializer.toJson<String>(rowKey),
      'value': serializer.toJson<String?>(value),
    };
  }

  SyncKvRow copyWith({
    String? rowKey,
    Value<String?> value = const Value.absent(),
  }) => SyncKvRow(
    rowKey: rowKey ?? this.rowKey,
    value: value.present ? value.value : this.value,
  );
  SyncKvRow copyWithCompanion(SyncKvCompanion data) {
    return SyncKvRow(
      rowKey: data.rowKey.present ? data.rowKey.value : this.rowKey,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncKvRow(')
          ..write('rowKey: $rowKey, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(rowKey, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncKvRow &&
          other.rowKey == this.rowKey &&
          other.value == this.value);
}

class SyncKvCompanion extends UpdateCompanion<SyncKvRow> {
  final Value<String> rowKey;
  final Value<String?> value;
  final Value<int> rowid;
  const SyncKvCompanion({
    this.rowKey = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncKvCompanion.insert({
    required String rowKey,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : rowKey = Value(rowKey);
  static Insertable<SyncKvRow> custom({
    Expression<String>? rowKey,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (rowKey != null) 'row_key': rowKey,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncKvCompanion copyWith({
    Value<String>? rowKey,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return SyncKvCompanion(
      rowKey: rowKey ?? this.rowKey,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rowKey.present) {
      map['row_key'] = Variable<String>(rowKey.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncKvCompanion(')
          ..write('rowKey: $rowKey, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InstalledToolsTable extends InstalledTools
    with TableInfo<$InstalledToolsTable, InstalledToolRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InstalledToolsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _toolIdMeta = const VerificationMeta('toolId');
  @override
  late final GeneratedColumn<String> toolId = GeneratedColumn<String>(
    'tool_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _installedAtMeta = const VerificationMeta(
    'installedAt',
  );
  @override
  late final GeneratedColumn<DateTime> installedAt = GeneratedColumn<DateTime>(
    'installed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('installed'),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metadataJsonMeta = const VerificationMeta(
    'metadataJson',
  );
  @override
  late final GeneratedColumn<String> metadataJson = GeneratedColumn<String>(
    'metadata_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    toolId,
    version,
    installedAt,
    updatedAt,
    status,
    source,
    metadataJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'installed_tools';
  @override
  VerificationContext validateIntegrity(
    Insertable<InstalledToolRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tool_id')) {
      context.handle(
        _toolIdMeta,
        toolId.isAcceptableOrUnknown(data['tool_id']!, _toolIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toolIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('installed_at')) {
      context.handle(
        _installedAtMeta,
        installedAt.isAcceptableOrUnknown(
          data['installed_at']!,
          _installedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_installedAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('metadata_json')) {
      context.handle(
        _metadataJsonMeta,
        metadataJson.isAcceptableOrUnknown(
          data['metadata_json']!,
          _metadataJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_metadataJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InstalledToolRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InstalledToolRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      toolId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tool_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      installedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}installed_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      metadataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata_json'],
      )!,
    );
  }

  @override
  $InstalledToolsTable createAlias(String alias) {
    return $InstalledToolsTable(attachedDatabase, alias);
  }
}

class InstalledToolRow extends DataClass
    implements Insertable<InstalledToolRow> {
  final int id;
  final String toolId;
  final String version;
  final DateTime installedAt;
  final DateTime updatedAt;
  final String status;
  final String? source;
  final String metadataJson;
  const InstalledToolRow({
    required this.id,
    required this.toolId,
    required this.version,
    required this.installedAt,
    required this.updatedAt,
    required this.status,
    this.source,
    required this.metadataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tool_id'] = Variable<String>(toolId);
    map['version'] = Variable<String>(version);
    map['installed_at'] = Variable<DateTime>(installedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    map['metadata_json'] = Variable<String>(metadataJson);
    return map;
  }

  InstalledToolsCompanion toCompanion(bool nullToAbsent) {
    return InstalledToolsCompanion(
      id: Value(id),
      toolId: Value(toolId),
      version: Value(version),
      installedAt: Value(installedAt),
      updatedAt: Value(updatedAt),
      status: Value(status),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      metadataJson: Value(metadataJson),
    );
  }

  factory InstalledToolRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InstalledToolRow(
      id: serializer.fromJson<int>(json['id']),
      toolId: serializer.fromJson<String>(json['toolId']),
      version: serializer.fromJson<String>(json['version']),
      installedAt: serializer.fromJson<DateTime>(json['installedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      status: serializer.fromJson<String>(json['status']),
      source: serializer.fromJson<String?>(json['source']),
      metadataJson: serializer.fromJson<String>(json['metadataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'toolId': serializer.toJson<String>(toolId),
      'version': serializer.toJson<String>(version),
      'installedAt': serializer.toJson<DateTime>(installedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'status': serializer.toJson<String>(status),
      'source': serializer.toJson<String?>(source),
      'metadataJson': serializer.toJson<String>(metadataJson),
    };
  }

  InstalledToolRow copyWith({
    int? id,
    String? toolId,
    String? version,
    DateTime? installedAt,
    DateTime? updatedAt,
    String? status,
    Value<String?> source = const Value.absent(),
    String? metadataJson,
  }) => InstalledToolRow(
    id: id ?? this.id,
    toolId: toolId ?? this.toolId,
    version: version ?? this.version,
    installedAt: installedAt ?? this.installedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
    source: source.present ? source.value : this.source,
    metadataJson: metadataJson ?? this.metadataJson,
  );
  InstalledToolRow copyWithCompanion(InstalledToolsCompanion data) {
    return InstalledToolRow(
      id: data.id.present ? data.id.value : this.id,
      toolId: data.toolId.present ? data.toolId.value : this.toolId,
      version: data.version.present ? data.version.value : this.version,
      installedAt: data.installedAt.present
          ? data.installedAt.value
          : this.installedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
      source: data.source.present ? data.source.value : this.source,
      metadataJson: data.metadataJson.present
          ? data.metadataJson.value
          : this.metadataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InstalledToolRow(')
          ..write('id: $id, ')
          ..write('toolId: $toolId, ')
          ..write('version: $version, ')
          ..write('installedAt: $installedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('source: $source, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    toolId,
    version,
    installedAt,
    updatedAt,
    status,
    source,
    metadataJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InstalledToolRow &&
          other.id == this.id &&
          other.toolId == this.toolId &&
          other.version == this.version &&
          other.installedAt == this.installedAt &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status &&
          other.source == this.source &&
          other.metadataJson == this.metadataJson);
}

class InstalledToolsCompanion extends UpdateCompanion<InstalledToolRow> {
  final Value<int> id;
  final Value<String> toolId;
  final Value<String> version;
  final Value<DateTime> installedAt;
  final Value<DateTime> updatedAt;
  final Value<String> status;
  final Value<String?> source;
  final Value<String> metadataJson;
  const InstalledToolsCompanion({
    this.id = const Value.absent(),
    this.toolId = const Value.absent(),
    this.version = const Value.absent(),
    this.installedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.source = const Value.absent(),
    this.metadataJson = const Value.absent(),
  });
  InstalledToolsCompanion.insert({
    this.id = const Value.absent(),
    required String toolId,
    this.version = const Value.absent(),
    required DateTime installedAt,
    required DateTime updatedAt,
    this.status = const Value.absent(),
    this.source = const Value.absent(),
    required String metadataJson,
  }) : toolId = Value(toolId),
       installedAt = Value(installedAt),
       updatedAt = Value(updatedAt),
       metadataJson = Value(metadataJson);
  static Insertable<InstalledToolRow> custom({
    Expression<int>? id,
    Expression<String>? toolId,
    Expression<String>? version,
    Expression<DateTime>? installedAt,
    Expression<DateTime>? updatedAt,
    Expression<String>? status,
    Expression<String>? source,
    Expression<String>? metadataJson,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (toolId != null) 'tool_id': toolId,
      if (version != null) 'version': version,
      if (installedAt != null) 'installed_at': installedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (source != null) 'source': source,
      if (metadataJson != null) 'metadata_json': metadataJson,
    });
  }

  InstalledToolsCompanion copyWith({
    Value<int>? id,
    Value<String>? toolId,
    Value<String>? version,
    Value<DateTime>? installedAt,
    Value<DateTime>? updatedAt,
    Value<String>? status,
    Value<String?>? source,
    Value<String>? metadataJson,
  }) {
    return InstalledToolsCompanion(
      id: id ?? this.id,
      toolId: toolId ?? this.toolId,
      version: version ?? this.version,
      installedAt: installedAt ?? this.installedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      source: source ?? this.source,
      metadataJson: metadataJson ?? this.metadataJson,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (toolId.present) {
      map['tool_id'] = Variable<String>(toolId.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (installedAt.present) {
      map['installed_at'] = Variable<DateTime>(installedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (metadataJson.present) {
      map['metadata_json'] = Variable<String>(metadataJson.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InstalledToolsCompanion(')
          ..write('id: $id, ')
          ..write('toolId: $toolId, ')
          ..write('version: $version, ')
          ..write('installedAt: $installedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('source: $source, ')
          ..write('metadataJson: $metadataJson')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CatCategoriesTable catCategories = $CatCategoriesTable(this);
  late final $CatPluginPagesTable catPluginPages = $CatPluginPagesTable(this);
  late final $CatPluginDetailsTable catPluginDetails = $CatPluginDetailsTable(
    this,
  );
  late final $CatPluginVersionsTable catPluginVersions =
      $CatPluginVersionsTable(this);
  late final $SyncKvTable syncKv = $SyncKvTable(this);
  late final $InstalledToolsTable installedTools = $InstalledToolsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    catCategories,
    catPluginPages,
    catPluginDetails,
    catPluginVersions,
    syncKv,
    installedTools,
  ];
}

typedef $$CatCategoriesTableCreateCompanionBuilder =
    CatCategoriesCompanion Function({
      Value<int> id,
      required String itemsJson,
      required DateTime cachedAt,
    });
typedef $$CatCategoriesTableUpdateCompanionBuilder =
    CatCategoriesCompanion Function({
      Value<int> id,
      Value<String> itemsJson,
      Value<DateTime> cachedAt,
    });

class $$CatCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CatCategoriesTable> {
  $$CatCategoriesTableFilterComposer({
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

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CatCategoriesTable> {
  $$CatCategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatCategoriesTable> {
  $$CatCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CatCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatCategoriesTable,
          CatCategoriesRow,
          $$CatCategoriesTableFilterComposer,
          $$CatCategoriesTableOrderingComposer,
          $$CatCategoriesTableAnnotationComposer,
          $$CatCategoriesTableCreateCompanionBuilder,
          $$CatCategoriesTableUpdateCompanionBuilder,
          (
            CatCategoriesRow,
            BaseReferences<
              _$AppDatabase,
              $CatCategoriesTable,
              CatCategoriesRow
            >,
          ),
          CatCategoriesRow,
          PrefetchHooks Function()
        > {
  $$CatCategoriesTableTableManager(_$AppDatabase db, $CatCategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => CatCategoriesCompanion(
                id: id,
                itemsJson: itemsJson,
                cachedAt: cachedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String itemsJson,
                required DateTime cachedAt,
              }) => CatCategoriesCompanion.insert(
                id: id,
                itemsJson: itemsJson,
                cachedAt: cachedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatCategoriesTable,
      CatCategoriesRow,
      $$CatCategoriesTableFilterComposer,
      $$CatCategoriesTableOrderingComposer,
      $$CatCategoriesTableAnnotationComposer,
      $$CatCategoriesTableCreateCompanionBuilder,
      $$CatCategoriesTableUpdateCompanionBuilder,
      (
        CatCategoriesRow,
        BaseReferences<_$AppDatabase, $CatCategoriesTable, CatCategoriesRow>,
      ),
      CatCategoriesRow,
      PrefetchHooks Function()
    >;
typedef $$CatPluginPagesTableCreateCompanionBuilder =
    CatPluginPagesCompanion Function({
      required String pageKey,
      required String itemsJson,
      Value<String?> nextCursor,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CatPluginPagesTableUpdateCompanionBuilder =
    CatPluginPagesCompanion Function({
      Value<String> pageKey,
      Value<String> itemsJson,
      Value<String?> nextCursor,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CatPluginPagesTableFilterComposer
    extends Composer<_$AppDatabase, $CatPluginPagesTable> {
  $$CatPluginPagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get pageKey => $composableBuilder(
    column: $table.pageKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nextCursor => $composableBuilder(
    column: $table.nextCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatPluginPagesTableOrderingComposer
    extends Composer<_$AppDatabase, $CatPluginPagesTable> {
  $$CatPluginPagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get pageKey => $composableBuilder(
    column: $table.pageKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nextCursor => $composableBuilder(
    column: $table.nextCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatPluginPagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatPluginPagesTable> {
  $$CatPluginPagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get pageKey =>
      $composableBuilder(column: $table.pageKey, builder: (column) => column);

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<String> get nextCursor => $composableBuilder(
    column: $table.nextCursor,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CatPluginPagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatPluginPagesTable,
          CatPluginPageRow,
          $$CatPluginPagesTableFilterComposer,
          $$CatPluginPagesTableOrderingComposer,
          $$CatPluginPagesTableAnnotationComposer,
          $$CatPluginPagesTableCreateCompanionBuilder,
          $$CatPluginPagesTableUpdateCompanionBuilder,
          (
            CatPluginPageRow,
            BaseReferences<
              _$AppDatabase,
              $CatPluginPagesTable,
              CatPluginPageRow
            >,
          ),
          CatPluginPageRow,
          PrefetchHooks Function()
        > {
  $$CatPluginPagesTableTableManager(
    _$AppDatabase db,
    $CatPluginPagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatPluginPagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatPluginPagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatPluginPagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> pageKey = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<String?> nextCursor = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatPluginPagesCompanion(
                pageKey: pageKey,
                itemsJson: itemsJson,
                nextCursor: nextCursor,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String pageKey,
                required String itemsJson,
                Value<String?> nextCursor = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatPluginPagesCompanion.insert(
                pageKey: pageKey,
                itemsJson: itemsJson,
                nextCursor: nextCursor,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatPluginPagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatPluginPagesTable,
      CatPluginPageRow,
      $$CatPluginPagesTableFilterComposer,
      $$CatPluginPagesTableOrderingComposer,
      $$CatPluginPagesTableAnnotationComposer,
      $$CatPluginPagesTableCreateCompanionBuilder,
      $$CatPluginPagesTableUpdateCompanionBuilder,
      (
        CatPluginPageRow,
        BaseReferences<_$AppDatabase, $CatPluginPagesTable, CatPluginPageRow>,
      ),
      CatPluginPageRow,
      PrefetchHooks Function()
    >;
typedef $$CatPluginDetailsTableCreateCompanionBuilder =
    CatPluginDetailsCompanion Function({
      required String slugKey,
      required String pluginJson,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CatPluginDetailsTableUpdateCompanionBuilder =
    CatPluginDetailsCompanion Function({
      Value<String> slugKey,
      Value<String> pluginJson,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CatPluginDetailsTableFilterComposer
    extends Composer<_$AppDatabase, $CatPluginDetailsTable> {
  $$CatPluginDetailsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get slugKey => $composableBuilder(
    column: $table.slugKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pluginJson => $composableBuilder(
    column: $table.pluginJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatPluginDetailsTableOrderingComposer
    extends Composer<_$AppDatabase, $CatPluginDetailsTable> {
  $$CatPluginDetailsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get slugKey => $composableBuilder(
    column: $table.slugKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pluginJson => $composableBuilder(
    column: $table.pluginJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatPluginDetailsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatPluginDetailsTable> {
  $$CatPluginDetailsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get slugKey =>
      $composableBuilder(column: $table.slugKey, builder: (column) => column);

  GeneratedColumn<String> get pluginJson => $composableBuilder(
    column: $table.pluginJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CatPluginDetailsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatPluginDetailsTable,
          CatPluginDetailRow,
          $$CatPluginDetailsTableFilterComposer,
          $$CatPluginDetailsTableOrderingComposer,
          $$CatPluginDetailsTableAnnotationComposer,
          $$CatPluginDetailsTableCreateCompanionBuilder,
          $$CatPluginDetailsTableUpdateCompanionBuilder,
          (
            CatPluginDetailRow,
            BaseReferences<
              _$AppDatabase,
              $CatPluginDetailsTable,
              CatPluginDetailRow
            >,
          ),
          CatPluginDetailRow,
          PrefetchHooks Function()
        > {
  $$CatPluginDetailsTableTableManager(
    _$AppDatabase db,
    $CatPluginDetailsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatPluginDetailsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatPluginDetailsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatPluginDetailsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> slugKey = const Value.absent(),
                Value<String> pluginJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatPluginDetailsCompanion(
                slugKey: slugKey,
                pluginJson: pluginJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String slugKey,
                required String pluginJson,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatPluginDetailsCompanion.insert(
                slugKey: slugKey,
                pluginJson: pluginJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatPluginDetailsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatPluginDetailsTable,
      CatPluginDetailRow,
      $$CatPluginDetailsTableFilterComposer,
      $$CatPluginDetailsTableOrderingComposer,
      $$CatPluginDetailsTableAnnotationComposer,
      $$CatPluginDetailsTableCreateCompanionBuilder,
      $$CatPluginDetailsTableUpdateCompanionBuilder,
      (
        CatPluginDetailRow,
        BaseReferences<
          _$AppDatabase,
          $CatPluginDetailsTable,
          CatPluginDetailRow
        >,
      ),
      CatPluginDetailRow,
      PrefetchHooks Function()
    >;
typedef $$CatPluginVersionsTableCreateCompanionBuilder =
    CatPluginVersionsCompanion Function({
      required String slugKey,
      required String itemsJson,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$CatPluginVersionsTableUpdateCompanionBuilder =
    CatPluginVersionsCompanion Function({
      Value<String> slugKey,
      Value<String> itemsJson,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$CatPluginVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $CatPluginVersionsTable> {
  $$CatPluginVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get slugKey => $composableBuilder(
    column: $table.slugKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CatPluginVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $CatPluginVersionsTable> {
  $$CatPluginVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get slugKey => $composableBuilder(
    column: $table.slugKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CatPluginVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CatPluginVersionsTable> {
  $$CatPluginVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get slugKey =>
      $composableBuilder(column: $table.slugKey, builder: (column) => column);

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$CatPluginVersionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CatPluginVersionsTable,
          CatPluginVersionRow,
          $$CatPluginVersionsTableFilterComposer,
          $$CatPluginVersionsTableOrderingComposer,
          $$CatPluginVersionsTableAnnotationComposer,
          $$CatPluginVersionsTableCreateCompanionBuilder,
          $$CatPluginVersionsTableUpdateCompanionBuilder,
          (
            CatPluginVersionRow,
            BaseReferences<
              _$AppDatabase,
              $CatPluginVersionsTable,
              CatPluginVersionRow
            >,
          ),
          CatPluginVersionRow,
          PrefetchHooks Function()
        > {
  $$CatPluginVersionsTableTableManager(
    _$AppDatabase db,
    $CatPluginVersionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CatPluginVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CatPluginVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CatPluginVersionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> slugKey = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CatPluginVersionsCompanion(
                slugKey: slugKey,
                itemsJson: itemsJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String slugKey,
                required String itemsJson,
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => CatPluginVersionsCompanion.insert(
                slugKey: slugKey,
                itemsJson: itemsJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CatPluginVersionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CatPluginVersionsTable,
      CatPluginVersionRow,
      $$CatPluginVersionsTableFilterComposer,
      $$CatPluginVersionsTableOrderingComposer,
      $$CatPluginVersionsTableAnnotationComposer,
      $$CatPluginVersionsTableCreateCompanionBuilder,
      $$CatPluginVersionsTableUpdateCompanionBuilder,
      (
        CatPluginVersionRow,
        BaseReferences<
          _$AppDatabase,
          $CatPluginVersionsTable,
          CatPluginVersionRow
        >,
      ),
      CatPluginVersionRow,
      PrefetchHooks Function()
    >;
typedef $$SyncKvTableCreateCompanionBuilder =
    SyncKvCompanion Function({
      required String rowKey,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$SyncKvTableUpdateCompanionBuilder =
    SyncKvCompanion Function({
      Value<String> rowKey,
      Value<String?> value,
      Value<int> rowid,
    });

class $$SyncKvTableFilterComposer
    extends Composer<_$AppDatabase, $SyncKvTable> {
  $$SyncKvTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get rowKey => $composableBuilder(
    column: $table.rowKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncKvTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncKvTable> {
  $$SyncKvTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get rowKey => $composableBuilder(
    column: $table.rowKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncKvTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncKvTable> {
  $$SyncKvTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get rowKey =>
      $composableBuilder(column: $table.rowKey, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncKvTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncKvTable,
          SyncKvRow,
          $$SyncKvTableFilterComposer,
          $$SyncKvTableOrderingComposer,
          $$SyncKvTableAnnotationComposer,
          $$SyncKvTableCreateCompanionBuilder,
          $$SyncKvTableUpdateCompanionBuilder,
          (SyncKvRow, BaseReferences<_$AppDatabase, $SyncKvTable, SyncKvRow>),
          SyncKvRow,
          PrefetchHooks Function()
        > {
  $$SyncKvTableTableManager(_$AppDatabase db, $SyncKvTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncKvTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncKvTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncKvTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> rowKey = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncKvCompanion(rowKey: rowKey, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String rowKey,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncKvCompanion.insert(
                rowKey: rowKey,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncKvTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncKvTable,
      SyncKvRow,
      $$SyncKvTableFilterComposer,
      $$SyncKvTableOrderingComposer,
      $$SyncKvTableAnnotationComposer,
      $$SyncKvTableCreateCompanionBuilder,
      $$SyncKvTableUpdateCompanionBuilder,
      (SyncKvRow, BaseReferences<_$AppDatabase, $SyncKvTable, SyncKvRow>),
      SyncKvRow,
      PrefetchHooks Function()
    >;
typedef $$InstalledToolsTableCreateCompanionBuilder =
    InstalledToolsCompanion Function({
      Value<int> id,
      required String toolId,
      Value<String> version,
      required DateTime installedAt,
      required DateTime updatedAt,
      Value<String> status,
      Value<String?> source,
      required String metadataJson,
    });
typedef $$InstalledToolsTableUpdateCompanionBuilder =
    InstalledToolsCompanion Function({
      Value<int> id,
      Value<String> toolId,
      Value<String> version,
      Value<DateTime> installedAt,
      Value<DateTime> updatedAt,
      Value<String> status,
      Value<String?> source,
      Value<String> metadataJson,
    });

class $$InstalledToolsTableFilterComposer
    extends Composer<_$AppDatabase, $InstalledToolsTable> {
  $$InstalledToolsTableFilterComposer({
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

  ColumnFilters<String> get toolId => $composableBuilder(
    column: $table.toolId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InstalledToolsTableOrderingComposer
    extends Composer<_$AppDatabase, $InstalledToolsTable> {
  $$InstalledToolsTableOrderingComposer({
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

  ColumnOrderings<String> get toolId => $composableBuilder(
    column: $table.toolId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InstalledToolsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InstalledToolsTable> {
  $$InstalledToolsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get toolId =>
      $composableBuilder(column: $table.toolId, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get installedAt => $composableBuilder(
    column: $table.installedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get metadataJson => $composableBuilder(
    column: $table.metadataJson,
    builder: (column) => column,
  );
}

class $$InstalledToolsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InstalledToolsTable,
          InstalledToolRow,
          $$InstalledToolsTableFilterComposer,
          $$InstalledToolsTableOrderingComposer,
          $$InstalledToolsTableAnnotationComposer,
          $$InstalledToolsTableCreateCompanionBuilder,
          $$InstalledToolsTableUpdateCompanionBuilder,
          (
            InstalledToolRow,
            BaseReferences<
              _$AppDatabase,
              $InstalledToolsTable,
              InstalledToolRow
            >,
          ),
          InstalledToolRow,
          PrefetchHooks Function()
        > {
  $$InstalledToolsTableTableManager(
    _$AppDatabase db,
    $InstalledToolsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InstalledToolsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InstalledToolsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InstalledToolsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> toolId = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<DateTime> installedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<String> metadataJson = const Value.absent(),
              }) => InstalledToolsCompanion(
                id: id,
                toolId: toolId,
                version: version,
                installedAt: installedAt,
                updatedAt: updatedAt,
                status: status,
                source: source,
                metadataJson: metadataJson,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String toolId,
                Value<String> version = const Value.absent(),
                required DateTime installedAt,
                required DateTime updatedAt,
                Value<String> status = const Value.absent(),
                Value<String?> source = const Value.absent(),
                required String metadataJson,
              }) => InstalledToolsCompanion.insert(
                id: id,
                toolId: toolId,
                version: version,
                installedAt: installedAt,
                updatedAt: updatedAt,
                status: status,
                source: source,
                metadataJson: metadataJson,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InstalledToolsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InstalledToolsTable,
      InstalledToolRow,
      $$InstalledToolsTableFilterComposer,
      $$InstalledToolsTableOrderingComposer,
      $$InstalledToolsTableAnnotationComposer,
      $$InstalledToolsTableCreateCompanionBuilder,
      $$InstalledToolsTableUpdateCompanionBuilder,
      (
        InstalledToolRow,
        BaseReferences<_$AppDatabase, $InstalledToolsTable, InstalledToolRow>,
      ),
      InstalledToolRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CatCategoriesTableTableManager get catCategories =>
      $$CatCategoriesTableTableManager(_db, _db.catCategories);
  $$CatPluginPagesTableTableManager get catPluginPages =>
      $$CatPluginPagesTableTableManager(_db, _db.catPluginPages);
  $$CatPluginDetailsTableTableManager get catPluginDetails =>
      $$CatPluginDetailsTableTableManager(_db, _db.catPluginDetails);
  $$CatPluginVersionsTableTableManager get catPluginVersions =>
      $$CatPluginVersionsTableTableManager(_db, _db.catPluginVersions);
  $$SyncKvTableTableManager get syncKv =>
      $$SyncKvTableTableManager(_db, _db.syncKv);
  $$InstalledToolsTableTableManager get installedTools =>
      $$InstalledToolsTableTableManager(_db, _db.installedTools);
}
