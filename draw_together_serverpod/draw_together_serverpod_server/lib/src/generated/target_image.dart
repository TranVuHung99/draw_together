/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import 'dart:typed_data' as _i2;

abstract class TargetImage
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  TargetImage._({
    this.id,
    required this.roomId,
    this.playerId,
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
  });

  factory TargetImage({
    int? id,
    required int roomId,
    int? playerId,
    required _i2.ByteData bytes,
    required String mimeType,
    required int width,
    required int height,
  }) = _TargetImageImpl;

  factory TargetImage.fromJson(Map<String, dynamic> jsonSerialization) {
    return TargetImage(
      id: jsonSerialization['id'] as int?,
      roomId: jsonSerialization['roomId'] as int,
      playerId: jsonSerialization['playerId'] as int?,
      bytes: _i1.ByteDataJsonExtension.fromJson(jsonSerialization['bytes']),
      mimeType: jsonSerialization['mimeType'] as String,
      width: jsonSerialization['width'] as int,
      height: jsonSerialization['height'] as int,
    );
  }

  static final t = TargetImageTable();

  static const db = TargetImageRepository._();

  @override
  int? id;

  int roomId;

  int? playerId;

  _i2.ByteData bytes;

  String mimeType;

  int width;

  int height;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [TargetImage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  TargetImage copyWith({
    int? id,
    int? roomId,
    int? playerId,
    _i2.ByteData? bytes,
    String? mimeType,
    int? width,
    int? height,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'TargetImage',
      if (id != null) 'id': id,
      'roomId': roomId,
      if (playerId != null) 'playerId': playerId,
      'bytes': bytes.toJson(),
      'mimeType': mimeType,
      'width': width,
      'height': height,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'TargetImage',
      if (id != null) 'id': id,
      'roomId': roomId,
      if (playerId != null) 'playerId': playerId,
      'bytes': bytes.toJson(),
      'mimeType': mimeType,
      'width': width,
      'height': height,
    };
  }

  static TargetImageInclude include() {
    return TargetImageInclude._();
  }

  static TargetImageIncludeList includeList({
    _i1.WhereExpressionBuilder<TargetImageTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<TargetImageTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<TargetImageTable>? orderByList,
    TargetImageInclude? include,
  }) {
    return TargetImageIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(TargetImage.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(TargetImage.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _TargetImageImpl extends TargetImage {
  _TargetImageImpl({
    int? id,
    required int roomId,
    int? playerId,
    required _i2.ByteData bytes,
    required String mimeType,
    required int width,
    required int height,
  }) : super._(
         id: id,
         roomId: roomId,
         playerId: playerId,
         bytes: bytes,
         mimeType: mimeType,
         width: width,
         height: height,
       );

  /// Returns a shallow copy of this [TargetImage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  TargetImage copyWith({
    Object? id = _Undefined,
    int? roomId,
    Object? playerId = _Undefined,
    _i2.ByteData? bytes,
    String? mimeType,
    int? width,
    int? height,
  }) {
    return TargetImage(
      id: id is int? ? id : this.id,
      roomId: roomId ?? this.roomId,
      playerId: playerId is int? ? playerId : this.playerId,
      bytes: bytes ?? this.bytes.clone(),
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

class TargetImageUpdateTable extends _i1.UpdateTable<TargetImageTable> {
  TargetImageUpdateTable(super.table);

  _i1.ColumnValue<int, int> roomId(int value) => _i1.ColumnValue(
    table.roomId,
    value,
  );

  _i1.ColumnValue<int, int> playerId(int? value) => _i1.ColumnValue(
    table.playerId,
    value,
  );

  _i1.ColumnValue<_i2.ByteData, _i2.ByteData> bytes(_i2.ByteData value) =>
      _i1.ColumnValue(
        table.bytes,
        value,
      );

  _i1.ColumnValue<String, String> mimeType(String value) => _i1.ColumnValue(
    table.mimeType,
    value,
  );

  _i1.ColumnValue<int, int> width(int value) => _i1.ColumnValue(
    table.width,
    value,
  );

  _i1.ColumnValue<int, int> height(int value) => _i1.ColumnValue(
    table.height,
    value,
  );
}

class TargetImageTable extends _i1.Table<int?> {
  TargetImageTable({super.tableRelation}) : super(tableName: 'target_image') {
    updateTable = TargetImageUpdateTable(this);
    roomId = _i1.ColumnInt(
      'roomId',
      this,
    );
    playerId = _i1.ColumnInt(
      'playerId',
      this,
    );
    bytes = _i1.ColumnByteData(
      'bytes',
      this,
    );
    mimeType = _i1.ColumnString(
      'mimeType',
      this,
    );
    width = _i1.ColumnInt(
      'width',
      this,
    );
    height = _i1.ColumnInt(
      'height',
      this,
    );
  }

  late final TargetImageUpdateTable updateTable;

  late final _i1.ColumnInt roomId;

  late final _i1.ColumnInt playerId;

  late final _i1.ColumnByteData bytes;

  late final _i1.ColumnString mimeType;

  late final _i1.ColumnInt width;

  late final _i1.ColumnInt height;

  @override
  List<_i1.Column> get columns => [
    id,
    roomId,
    playerId,
    bytes,
    mimeType,
    width,
    height,
  ];
}

class TargetImageInclude extends _i1.IncludeObject {
  TargetImageInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => TargetImage.t;
}

class TargetImageIncludeList extends _i1.IncludeList {
  TargetImageIncludeList._({
    _i1.WhereExpressionBuilder<TargetImageTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(TargetImage.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => TargetImage.t;
}

class TargetImageRepository {
  const TargetImageRepository._();

  /// Returns a list of [TargetImage]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<TargetImage>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<TargetImageTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<TargetImageTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<TargetImageTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<TargetImage>(
      where: where?.call(TargetImage.t),
      orderBy: orderBy?.call(TargetImage.t),
      orderByList: orderByList?.call(TargetImage.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [TargetImage] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<TargetImage?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<TargetImageTable>? where,
    int? offset,
    _i1.OrderByBuilder<TargetImageTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<TargetImageTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<TargetImage>(
      where: where?.call(TargetImage.t),
      orderBy: orderBy?.call(TargetImage.t),
      orderByList: orderByList?.call(TargetImage.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [TargetImage] by its [id] or null if no such row exists.
  Future<TargetImage?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<TargetImage>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [TargetImage]s in the list and returns the inserted rows.
  ///
  /// The returned [TargetImage]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<TargetImage>> insert(
    _i1.Session session,
    List<TargetImage> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<TargetImage>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [TargetImage] and returns the inserted row.
  ///
  /// The returned [TargetImage] will have its `id` field set.
  Future<TargetImage> insertRow(
    _i1.Session session,
    TargetImage row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<TargetImage>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [TargetImage]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<TargetImage>> update(
    _i1.Session session,
    List<TargetImage> rows, {
    _i1.ColumnSelections<TargetImageTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<TargetImage>(
      rows,
      columns: columns?.call(TargetImage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [TargetImage]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<TargetImage> updateRow(
    _i1.Session session,
    TargetImage row, {
    _i1.ColumnSelections<TargetImageTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<TargetImage>(
      row,
      columns: columns?.call(TargetImage.t),
      transaction: transaction,
    );
  }

  /// Updates a single [TargetImage] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<TargetImage?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<TargetImageUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<TargetImage>(
      id,
      columnValues: columnValues(TargetImage.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [TargetImage]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<TargetImage>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<TargetImageUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<TargetImageTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<TargetImageTable>? orderBy,
    _i1.OrderByListBuilder<TargetImageTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<TargetImage>(
      columnValues: columnValues(TargetImage.t.updateTable),
      where: where(TargetImage.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(TargetImage.t),
      orderByList: orderByList?.call(TargetImage.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [TargetImage]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<TargetImage>> delete(
    _i1.Session session,
    List<TargetImage> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<TargetImage>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [TargetImage].
  Future<TargetImage> deleteRow(
    _i1.Session session,
    TargetImage row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<TargetImage>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<TargetImage>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<TargetImageTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<TargetImage>(
      where: where(TargetImage.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<TargetImageTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<TargetImage>(
      where: where?.call(TargetImage.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
