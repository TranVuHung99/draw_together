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

abstract class Room implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  Room._({
    this.id,
    required this.roomCode,
    required this.hostId,
    required this.status,
    required this.canvasWidth,
    required this.canvasHeight,
    this.endTime,
    this.pausedAt,
    this.remainingMs,
    this.finalSvg,
  });

  factory Room({
    int? id,
    required String roomCode,
    required int hostId,
    required String status,
    required double canvasWidth,
    required double canvasHeight,
    DateTime? endTime,
    DateTime? pausedAt,
    int? remainingMs,
    String? finalSvg,
  }) = _RoomImpl;

  factory Room.fromJson(Map<String, dynamic> jsonSerialization) {
    return Room(
      id: jsonSerialization['id'] as int?,
      roomCode: jsonSerialization['roomCode'] as String,
      hostId: jsonSerialization['hostId'] as int,
      status: jsonSerialization['status'] as String,
      canvasWidth: (jsonSerialization['canvasWidth'] as num).toDouble(),
      canvasHeight: (jsonSerialization['canvasHeight'] as num).toDouble(),
      endTime: jsonSerialization['endTime'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['endTime']),
      pausedAt: jsonSerialization['pausedAt'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['pausedAt']),
      remainingMs: jsonSerialization['remainingMs'] as int?,
      finalSvg: jsonSerialization['finalSvg'] as String?,
    );
  }

  static final t = RoomTable();

  static const db = RoomRepository._();

  @override
  int? id;

  String roomCode;

  int hostId;

  String status;

  double canvasWidth;

  double canvasHeight;

  DateTime? endTime;

  DateTime? pausedAt;

  int? remainingMs;

  String? finalSvg;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [Room]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Room copyWith({
    int? id,
    String? roomCode,
    int? hostId,
    String? status,
    double? canvasWidth,
    double? canvasHeight,
    DateTime? endTime,
    DateTime? pausedAt,
    int? remainingMs,
    String? finalSvg,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Room',
      if (id != null) 'id': id,
      'roomCode': roomCode,
      'hostId': hostId,
      'status': status,
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
      if (endTime != null) 'endTime': endTime?.toJson(),
      if (pausedAt != null) 'pausedAt': pausedAt?.toJson(),
      if (remainingMs != null) 'remainingMs': remainingMs,
      if (finalSvg != null) 'finalSvg': finalSvg,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Room',
      if (id != null) 'id': id,
      'roomCode': roomCode,
      'hostId': hostId,
      'status': status,
      'canvasWidth': canvasWidth,
      'canvasHeight': canvasHeight,
      if (endTime != null) 'endTime': endTime?.toJson(),
      if (pausedAt != null) 'pausedAt': pausedAt?.toJson(),
      if (remainingMs != null) 'remainingMs': remainingMs,
      if (finalSvg != null) 'finalSvg': finalSvg,
    };
  }

  static RoomInclude include() {
    return RoomInclude._();
  }

  static RoomIncludeList includeList({
    _i1.WhereExpressionBuilder<RoomTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RoomTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<RoomTable>? orderByList,
    RoomInclude? include,
  }) {
    return RoomIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Room.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(Room.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RoomImpl extends Room {
  _RoomImpl({
    int? id,
    required String roomCode,
    required int hostId,
    required String status,
    required double canvasWidth,
    required double canvasHeight,
    DateTime? endTime,
    DateTime? pausedAt,
    int? remainingMs,
    String? finalSvg,
  }) : super._(
         id: id,
         roomCode: roomCode,
         hostId: hostId,
         status: status,
         canvasWidth: canvasWidth,
         canvasHeight: canvasHeight,
         endTime: endTime,
         pausedAt: pausedAt,
         remainingMs: remainingMs,
         finalSvg: finalSvg,
       );

  /// Returns a shallow copy of this [Room]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Room copyWith({
    Object? id = _Undefined,
    String? roomCode,
    int? hostId,
    String? status,
    double? canvasWidth,
    double? canvasHeight,
    Object? endTime = _Undefined,
    Object? pausedAt = _Undefined,
    Object? remainingMs = _Undefined,
    Object? finalSvg = _Undefined,
  }) {
    return Room(
      id: id is int? ? id : this.id,
      roomCode: roomCode ?? this.roomCode,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      endTime: endTime is DateTime? ? endTime : this.endTime,
      pausedAt: pausedAt is DateTime? ? pausedAt : this.pausedAt,
      remainingMs: remainingMs is int? ? remainingMs : this.remainingMs,
      finalSvg: finalSvg is String? ? finalSvg : this.finalSvg,
    );
  }
}

class RoomUpdateTable extends _i1.UpdateTable<RoomTable> {
  RoomUpdateTable(super.table);

  _i1.ColumnValue<String, String> roomCode(String value) => _i1.ColumnValue(
    table.roomCode,
    value,
  );

  _i1.ColumnValue<int, int> hostId(int value) => _i1.ColumnValue(
    table.hostId,
    value,
  );

  _i1.ColumnValue<String, String> status(String value) => _i1.ColumnValue(
    table.status,
    value,
  );

  _i1.ColumnValue<double, double> canvasWidth(double value) => _i1.ColumnValue(
    table.canvasWidth,
    value,
  );

  _i1.ColumnValue<double, double> canvasHeight(double value) => _i1.ColumnValue(
    table.canvasHeight,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> endTime(DateTime? value) =>
      _i1.ColumnValue(
        table.endTime,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> pausedAt(DateTime? value) =>
      _i1.ColumnValue(
        table.pausedAt,
        value,
      );

  _i1.ColumnValue<int, int> remainingMs(int? value) => _i1.ColumnValue(
    table.remainingMs,
    value,
  );

  _i1.ColumnValue<String, String> finalSvg(String? value) => _i1.ColumnValue(
    table.finalSvg,
    value,
  );
}

class RoomTable extends _i1.Table<int?> {
  RoomTable({super.tableRelation}) : super(tableName: 'room') {
    updateTable = RoomUpdateTable(this);
    roomCode = _i1.ColumnString(
      'roomCode',
      this,
    );
    hostId = _i1.ColumnInt(
      'hostId',
      this,
    );
    status = _i1.ColumnString(
      'status',
      this,
    );
    canvasWidth = _i1.ColumnDouble(
      'canvasWidth',
      this,
    );
    canvasHeight = _i1.ColumnDouble(
      'canvasHeight',
      this,
    );
    endTime = _i1.ColumnDateTime(
      'endTime',
      this,
    );
    pausedAt = _i1.ColumnDateTime(
      'pausedAt',
      this,
    );
    remainingMs = _i1.ColumnInt(
      'remainingMs',
      this,
    );
    finalSvg = _i1.ColumnString(
      'finalSvg',
      this,
    );
  }

  late final RoomUpdateTable updateTable;

  late final _i1.ColumnString roomCode;

  late final _i1.ColumnInt hostId;

  late final _i1.ColumnString status;

  late final _i1.ColumnDouble canvasWidth;

  late final _i1.ColumnDouble canvasHeight;

  late final _i1.ColumnDateTime endTime;

  late final _i1.ColumnDateTime pausedAt;

  late final _i1.ColumnInt remainingMs;

  late final _i1.ColumnString finalSvg;

  @override
  List<_i1.Column> get columns => [
    id,
    roomCode,
    hostId,
    status,
    canvasWidth,
    canvasHeight,
    endTime,
    pausedAt,
    remainingMs,
    finalSvg,
  ];
}

class RoomInclude extends _i1.IncludeObject {
  RoomInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => Room.t;
}

class RoomIncludeList extends _i1.IncludeList {
  RoomIncludeList._({
    _i1.WhereExpressionBuilder<RoomTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Room.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => Room.t;
}

class RoomRepository {
  const RoomRepository._();

  /// Returns a list of [Room]s matching the given query parameters.
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
  Future<List<Room>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<RoomTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RoomTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<RoomTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<Room>(
      where: where?.call(Room.t),
      orderBy: orderBy?.call(Room.t),
      orderByList: orderByList?.call(Room.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [Room] matching the given query parameters.
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
  Future<Room?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<RoomTable>? where,
    int? offset,
    _i1.OrderByBuilder<RoomTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<RoomTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<Room>(
      where: where?.call(Room.t),
      orderBy: orderBy?.call(Room.t),
      orderByList: orderByList?.call(Room.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [Room] by its [id] or null if no such row exists.
  Future<Room?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<Room>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [Room]s in the list and returns the inserted rows.
  ///
  /// The returned [Room]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<Room>> insert(
    _i1.Session session,
    List<Room> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<Room>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [Room] and returns the inserted row.
  ///
  /// The returned [Room] will have its `id` field set.
  Future<Room> insertRow(
    _i1.Session session,
    Room row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Room>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [Room]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<Room>> update(
    _i1.Session session,
    List<Room> rows, {
    _i1.ColumnSelections<RoomTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<Room>(
      rows,
      columns: columns?.call(Room.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Room]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Room> updateRow(
    _i1.Session session,
    Room row, {
    _i1.ColumnSelections<RoomTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Room>(
      row,
      columns: columns?.call(Room.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Room] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Room?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<RoomUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<Room>(
      id,
      columnValues: columnValues(Room.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Room]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<Room>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<RoomUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<RoomTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<RoomTable>? orderBy,
    _i1.OrderByListBuilder<RoomTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<Room>(
      columnValues: columnValues(Room.t.updateTable),
      where: where(Room.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Room.t),
      orderByList: orderByList?.call(Room.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [Room]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<Room>> delete(
    _i1.Session session,
    List<Room> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Room>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [Room].
  Future<Room> deleteRow(
    _i1.Session session,
    Room row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Room>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<Room>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<RoomTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<Room>(
      where: where(Room.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<RoomTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Room>(
      where: where?.call(Room.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
