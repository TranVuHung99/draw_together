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
import 'package:draw_together_serverpod_server/src/generated/protocol.dart'
    as _i2;

abstract class Stroke implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
  Stroke._({
    this.id,
    required this.roomId,
    required this.playerId,
    required this.strokeId,
    required this.points,
    required this.colorInfo,
    required this.strokeWidth,
    required this.isEraser,
    required this.sequence,
    required this.timestamp,
  });

  factory Stroke({
    int? id,
    required int roomId,
    required int playerId,
    required String strokeId,
    required List<double> points,
    required String colorInfo,
    required double strokeWidth,
    required bool isEraser,
    required int sequence,
    required DateTime timestamp,
  }) = _StrokeImpl;

  factory Stroke.fromJson(Map<String, dynamic> jsonSerialization) {
    return Stroke(
      id: jsonSerialization['id'] as int?,
      roomId: jsonSerialization['roomId'] as int,
      playerId: jsonSerialization['playerId'] as int,
      strokeId: jsonSerialization['strokeId'] as String,
      points: _i2.Protocol().deserialize<List<double>>(
        jsonSerialization['points'],
      ),
      colorInfo: jsonSerialization['colorInfo'] as String,
      strokeWidth: (jsonSerialization['strokeWidth'] as num).toDouble(),
      isEraser: jsonSerialization['isEraser'] as bool,
      sequence: jsonSerialization['sequence'] as int,
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
    );
  }

  static final t = StrokeTable();

  static const db = StrokeRepository._();

  @override
  int? id;

  int roomId;

  int playerId;

  String strokeId;

  List<double> points;

  String colorInfo;

  double strokeWidth;

  bool isEraser;

  int sequence;

  DateTime timestamp;

  @override
  _i1.Table<int?> get table => t;

  /// Returns a shallow copy of this [Stroke]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Stroke copyWith({
    int? id,
    int? roomId,
    int? playerId,
    String? strokeId,
    List<double>? points,
    String? colorInfo,
    double? strokeWidth,
    bool? isEraser,
    int? sequence,
    DateTime? timestamp,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Stroke',
      if (id != null) 'id': id,
      'roomId': roomId,
      'playerId': playerId,
      'strokeId': strokeId,
      'points': points.toJson(),
      'colorInfo': colorInfo,
      'strokeWidth': strokeWidth,
      'isEraser': isEraser,
      'sequence': sequence,
      'timestamp': timestamp.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'Stroke',
      if (id != null) 'id': id,
      'roomId': roomId,
      'playerId': playerId,
      'strokeId': strokeId,
      'points': points.toJson(),
      'colorInfo': colorInfo,
      'strokeWidth': strokeWidth,
      'isEraser': isEraser,
      'sequence': sequence,
      'timestamp': timestamp.toJson(),
    };
  }

  static StrokeInclude include() {
    return StrokeInclude._();
  }

  static StrokeIncludeList includeList({
    _i1.WhereExpressionBuilder<StrokeTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<StrokeTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<StrokeTable>? orderByList,
    StrokeInclude? include,
  }) {
    return StrokeIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Stroke.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(Stroke.t),
      include: include,
    );
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _StrokeImpl extends Stroke {
  _StrokeImpl({
    int? id,
    required int roomId,
    required int playerId,
    required String strokeId,
    required List<double> points,
    required String colorInfo,
    required double strokeWidth,
    required bool isEraser,
    required int sequence,
    required DateTime timestamp,
  }) : super._(
         id: id,
         roomId: roomId,
         playerId: playerId,
         strokeId: strokeId,
         points: points,
         colorInfo: colorInfo,
         strokeWidth: strokeWidth,
         isEraser: isEraser,
         sequence: sequence,
         timestamp: timestamp,
       );

  /// Returns a shallow copy of this [Stroke]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Stroke copyWith({
    Object? id = _Undefined,
    int? roomId,
    int? playerId,
    String? strokeId,
    List<double>? points,
    String? colorInfo,
    double? strokeWidth,
    bool? isEraser,
    int? sequence,
    DateTime? timestamp,
  }) {
    return Stroke(
      id: id is int? ? id : this.id,
      roomId: roomId ?? this.roomId,
      playerId: playerId ?? this.playerId,
      strokeId: strokeId ?? this.strokeId,
      points: points ?? this.points.map((e0) => e0).toList(),
      colorInfo: colorInfo ?? this.colorInfo,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isEraser: isEraser ?? this.isEraser,
      sequence: sequence ?? this.sequence,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class StrokeUpdateTable extends _i1.UpdateTable<StrokeTable> {
  StrokeUpdateTable(super.table);

  _i1.ColumnValue<int, int> roomId(int value) => _i1.ColumnValue(
    table.roomId,
    value,
  );

  _i1.ColumnValue<int, int> playerId(int value) => _i1.ColumnValue(
    table.playerId,
    value,
  );

  _i1.ColumnValue<String, String> strokeId(String value) => _i1.ColumnValue(
    table.strokeId,
    value,
  );

  _i1.ColumnValue<List<double>, List<double>> points(List<double> value) =>
      _i1.ColumnValue(
        table.points,
        value,
      );

  _i1.ColumnValue<String, String> colorInfo(String value) => _i1.ColumnValue(
    table.colorInfo,
    value,
  );

  _i1.ColumnValue<double, double> strokeWidth(double value) => _i1.ColumnValue(
    table.strokeWidth,
    value,
  );

  _i1.ColumnValue<bool, bool> isEraser(bool value) => _i1.ColumnValue(
    table.isEraser,
    value,
  );

  _i1.ColumnValue<int, int> sequence(int value) => _i1.ColumnValue(
    table.sequence,
    value,
  );

  _i1.ColumnValue<DateTime, DateTime> timestamp(DateTime value) =>
      _i1.ColumnValue(
        table.timestamp,
        value,
      );
}

class StrokeTable extends _i1.Table<int?> {
  StrokeTable({super.tableRelation}) : super(tableName: 'stroke') {
    updateTable = StrokeUpdateTable(this);
    roomId = _i1.ColumnInt(
      'roomId',
      this,
    );
    playerId = _i1.ColumnInt(
      'playerId',
      this,
    );
    strokeId = _i1.ColumnString(
      'strokeId',
      this,
    );
    points = _i1.ColumnSerializable<List<double>>(
      'points',
      this,
    );
    colorInfo = _i1.ColumnString(
      'colorInfo',
      this,
    );
    strokeWidth = _i1.ColumnDouble(
      'strokeWidth',
      this,
    );
    isEraser = _i1.ColumnBool(
      'isEraser',
      this,
    );
    sequence = _i1.ColumnInt(
      'sequence',
      this,
    );
    timestamp = _i1.ColumnDateTime(
      'timestamp',
      this,
    );
  }

  late final StrokeUpdateTable updateTable;

  late final _i1.ColumnInt roomId;

  late final _i1.ColumnInt playerId;

  late final _i1.ColumnString strokeId;

  late final _i1.ColumnSerializable<List<double>> points;

  late final _i1.ColumnString colorInfo;

  late final _i1.ColumnDouble strokeWidth;

  late final _i1.ColumnBool isEraser;

  late final _i1.ColumnInt sequence;

  late final _i1.ColumnDateTime timestamp;

  @override
  List<_i1.Column> get columns => [
    id,
    roomId,
    playerId,
    strokeId,
    points,
    colorInfo,
    strokeWidth,
    isEraser,
    sequence,
    timestamp,
  ];
}

class StrokeInclude extends _i1.IncludeObject {
  StrokeInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => Stroke.t;
}

class StrokeIncludeList extends _i1.IncludeList {
  StrokeIncludeList._({
    _i1.WhereExpressionBuilder<StrokeTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Stroke.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => Stroke.t;
}

class StrokeRepository {
  const StrokeRepository._();

  /// Returns a list of [Stroke]s matching the given query parameters.
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
  Future<List<Stroke>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<StrokeTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<StrokeTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<StrokeTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<Stroke>(
      where: where?.call(Stroke.t),
      orderBy: orderBy?.call(Stroke.t),
      orderByList: orderByList?.call(Stroke.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [Stroke] matching the given query parameters.
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
  Future<Stroke?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<StrokeTable>? where,
    int? offset,
    _i1.OrderByBuilder<StrokeTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<StrokeTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<Stroke>(
      where: where?.call(Stroke.t),
      orderBy: orderBy?.call(Stroke.t),
      orderByList: orderByList?.call(Stroke.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [Stroke] by its [id] or null if no such row exists.
  Future<Stroke?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<Stroke>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [Stroke]s in the list and returns the inserted rows.
  ///
  /// The returned [Stroke]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<Stroke>> insert(
    _i1.Session session,
    List<Stroke> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<Stroke>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [Stroke] and returns the inserted row.
  ///
  /// The returned [Stroke] will have its `id` field set.
  Future<Stroke> insertRow(
    _i1.Session session,
    Stroke row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Stroke>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [Stroke]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<Stroke>> update(
    _i1.Session session,
    List<Stroke> rows, {
    _i1.ColumnSelections<StrokeTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<Stroke>(
      rows,
      columns: columns?.call(Stroke.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Stroke]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Stroke> updateRow(
    _i1.Session session,
    Stroke row, {
    _i1.ColumnSelections<StrokeTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Stroke>(
      row,
      columns: columns?.call(Stroke.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Stroke] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Stroke?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<StrokeUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<Stroke>(
      id,
      columnValues: columnValues(Stroke.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Stroke]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<Stroke>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<StrokeUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<StrokeTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<StrokeTable>? orderBy,
    _i1.OrderByListBuilder<StrokeTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<Stroke>(
      columnValues: columnValues(Stroke.t.updateTable),
      where: where(Stroke.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Stroke.t),
      orderByList: orderByList?.call(Stroke.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [Stroke]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<Stroke>> delete(
    _i1.Session session,
    List<Stroke> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Stroke>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [Stroke].
  Future<Stroke> deleteRow(
    _i1.Session session,
    Stroke row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Stroke>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<Stroke>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<StrokeTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<Stroke>(
      where: where(Stroke.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<StrokeTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Stroke>(
      where: where?.call(Stroke.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
