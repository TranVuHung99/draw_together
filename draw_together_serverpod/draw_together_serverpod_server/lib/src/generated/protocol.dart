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
import 'package:serverpod/protocol.dart' as _i2;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _i3;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _i4;
import 'final_canvas_msg.dart' as _i5;
import 'future_calls_generated_models/game_end_future_call_finalize_room_model.dart'
    as _i6;
import 'game_state_change_msg.dart' as _i7;
import 'greetings/greeting.dart' as _i8;
import 'player.dart' as _i9;
import 'room.dart' as _i10;
import 'room_subscribe_msg.dart' as _i11;
import 'stroke.dart' as _i12;
import 'stroke_rejected_msg.dart' as _i13;
import 'stroke_sync_msg.dart' as _i14;
import 'stroke_undo_msg.dart' as _i15;
import 'target_image.dart' as _i16;
import 'package:draw_together_serverpod_server/src/generated/player.dart'
    as _i17;
export 'final_canvas_msg.dart';
export 'game_state_change_msg.dart';
export 'greetings/greeting.dart';
export 'player.dart';
export 'room.dart';
export 'room_subscribe_msg.dart';
export 'stroke.dart';
export 'stroke_rejected_msg.dart';
export 'stroke_sync_msg.dart';
export 'stroke_undo_msg.dart';
export 'target_image.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    _i2.TableDefinition(
      name: 'player',
      dartName: 'Player',
      schema: 'public',
      module: 'draw_together_serverpod',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'player_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'roomId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'name',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'colorInfo',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
        _i2.ColumnDefinition(
          name: 'regionX',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _i2.ColumnDefinition(
          name: 'regionY',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _i2.ColumnDefinition(
          name: 'regionWidth',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
        _i2.ColumnDefinition(
          name: 'regionHeight',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: true,
          dartType: 'double?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'player_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'room',
      dartName: 'Room',
      schema: 'public',
      module: 'draw_together_serverpod',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'room_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'roomCode',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'hostId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'status',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'canvasWidth',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i2.ColumnDefinition(
          name: 'canvasHeight',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i2.ColumnDefinition(
          name: 'endTime',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'pausedAt',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: true,
          dartType: 'DateTime?',
        ),
        _i2.ColumnDefinition(
          name: 'remainingMs',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'finalSvg',
          columnType: _i2.ColumnType.text,
          isNullable: true,
          dartType: 'String?',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'room_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'stroke',
      dartName: 'Stroke',
      schema: 'public',
      module: 'draw_together_serverpod',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'stroke_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'roomId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'playerId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'strokeId',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'points',
          columnType: _i2.ColumnType.json,
          isNullable: false,
          dartType: 'List<double>',
        ),
        _i2.ColumnDefinition(
          name: 'colorInfo',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'strokeWidth',
          columnType: _i2.ColumnType.doublePrecision,
          isNullable: false,
          dartType: 'double',
        ),
        _i2.ColumnDefinition(
          name: 'isEraser',
          columnType: _i2.ColumnType.boolean,
          isNullable: false,
          dartType: 'bool',
        ),
        _i2.ColumnDefinition(
          name: 'sequence',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'timestamp',
          columnType: _i2.ColumnType.timestampWithoutTimeZone,
          isNullable: false,
          dartType: 'DateTime',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'stroke_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'stroke_room_seq_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'roomId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'sequence',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    _i2.TableDefinition(
      name: 'target_image',
      dartName: 'TargetImage',
      schema: 'public',
      module: 'draw_together_serverpod',
      columns: [
        _i2.ColumnDefinition(
          name: 'id',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int?',
          columnDefault: 'nextval(\'target_image_id_seq\'::regclass)',
        ),
        _i2.ColumnDefinition(
          name: 'roomId',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'playerId',
          columnType: _i2.ColumnType.bigint,
          isNullable: true,
          dartType: 'int?',
        ),
        _i2.ColumnDefinition(
          name: 'bytes',
          columnType: _i2.ColumnType.bytea,
          isNullable: false,
          dartType: 'dart:typed_data:ByteData',
        ),
        _i2.ColumnDefinition(
          name: 'mimeType',
          columnType: _i2.ColumnType.text,
          isNullable: false,
          dartType: 'String',
        ),
        _i2.ColumnDefinition(
          name: 'width',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
        _i2.ColumnDefinition(
          name: 'height',
          columnType: _i2.ColumnType.bigint,
          isNullable: false,
          dartType: 'int',
        ),
      ],
      foreignKeys: [],
      indexes: [
        _i2.IndexDefinition(
          indexName: 'target_image_pkey',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'id',
            ),
          ],
          type: 'btree',
          isUnique: true,
          isPrimary: true,
        ),
        _i2.IndexDefinition(
          indexName: 'target_image_room_player_idx',
          tableSpace: null,
          elements: [
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'roomId',
            ),
            _i2.IndexElementDefinition(
              type: _i2.IndexElementDefinitionType.column,
              definition: 'playerId',
            ),
          ],
          type: 'btree',
          isUnique: false,
          isPrimary: false,
        ),
      ],
      managed: true,
    ),
    ..._i3.Protocol.targetTableDefinitions,
    ..._i4.Protocol.targetTableDefinitions,
    ..._i2.Protocol.targetTableDefinitions,
  ];

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i5.FinalCanvasMsg) {
      return _i5.FinalCanvasMsg.fromJson(data) as T;
    }
    if (t == _i6.GameEndFutureCallFinalizeRoomModel) {
      return _i6.GameEndFutureCallFinalizeRoomModel.fromJson(data) as T;
    }
    if (t == _i7.GameStateChangeMsg) {
      return _i7.GameStateChangeMsg.fromJson(data) as T;
    }
    if (t == _i8.Greeting) {
      return _i8.Greeting.fromJson(data) as T;
    }
    if (t == _i9.Player) {
      return _i9.Player.fromJson(data) as T;
    }
    if (t == _i10.Room) {
      return _i10.Room.fromJson(data) as T;
    }
    if (t == _i11.RoomSubscribeMsg) {
      return _i11.RoomSubscribeMsg.fromJson(data) as T;
    }
    if (t == _i12.Stroke) {
      return _i12.Stroke.fromJson(data) as T;
    }
    if (t == _i13.StrokeRejectedMsg) {
      return _i13.StrokeRejectedMsg.fromJson(data) as T;
    }
    if (t == _i14.StrokeSyncMsg) {
      return _i14.StrokeSyncMsg.fromJson(data) as T;
    }
    if (t == _i15.StrokeUndoMsg) {
      return _i15.StrokeUndoMsg.fromJson(data) as T;
    }
    if (t == _i16.TargetImage) {
      return _i16.TargetImage.fromJson(data) as T;
    }
    if (t == _i1.getType<_i5.FinalCanvasMsg?>()) {
      return (data != null ? _i5.FinalCanvasMsg.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.GameEndFutureCallFinalizeRoomModel?>()) {
      return (data != null
              ? _i6.GameEndFutureCallFinalizeRoomModel.fromJson(data)
              : null)
          as T;
    }
    if (t == _i1.getType<_i7.GameStateChangeMsg?>()) {
      return (data != null ? _i7.GameStateChangeMsg.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.Greeting?>()) {
      return (data != null ? _i8.Greeting.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.Player?>()) {
      return (data != null ? _i9.Player.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.Room?>()) {
      return (data != null ? _i10.Room.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.RoomSubscribeMsg?>()) {
      return (data != null ? _i11.RoomSubscribeMsg.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i12.Stroke?>()) {
      return (data != null ? _i12.Stroke.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i13.StrokeRejectedMsg?>()) {
      return (data != null ? _i13.StrokeRejectedMsg.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i14.StrokeSyncMsg?>()) {
      return (data != null ? _i14.StrokeSyncMsg.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i15.StrokeUndoMsg?>()) {
      return (data != null ? _i15.StrokeUndoMsg.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i16.TargetImage?>()) {
      return (data != null ? _i16.TargetImage.fromJson(data) : null) as T;
    }
    if (t == List<double>) {
      return (data as List).map((e) => deserialize<double>(e)).toList() as T;
    }
    if (t == List<_i17.Player>) {
      return (data as List).map((e) => deserialize<_i17.Player>(e)).toList()
          as T;
    }
    try {
      return _i3.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i4.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i5.FinalCanvasMsg => 'FinalCanvasMsg',
      _i6.GameEndFutureCallFinalizeRoomModel =>
        'GameEndFutureCallFinalizeRoomModel',
      _i7.GameStateChangeMsg => 'GameStateChangeMsg',
      _i8.Greeting => 'Greeting',
      _i9.Player => 'Player',
      _i10.Room => 'Room',
      _i11.RoomSubscribeMsg => 'RoomSubscribeMsg',
      _i12.Stroke => 'Stroke',
      _i13.StrokeRejectedMsg => 'StrokeRejectedMsg',
      _i14.StrokeSyncMsg => 'StrokeSyncMsg',
      _i15.StrokeUndoMsg => 'StrokeUndoMsg',
      _i16.TargetImage => 'TargetImage',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst(
        'draw_together_serverpod.',
        '',
      );
    }

    switch (data) {
      case _i5.FinalCanvasMsg():
        return 'FinalCanvasMsg';
      case _i6.GameEndFutureCallFinalizeRoomModel():
        return 'GameEndFutureCallFinalizeRoomModel';
      case _i7.GameStateChangeMsg():
        return 'GameStateChangeMsg';
      case _i8.Greeting():
        return 'Greeting';
      case _i9.Player():
        return 'Player';
      case _i10.Room():
        return 'Room';
      case _i11.RoomSubscribeMsg():
        return 'RoomSubscribeMsg';
      case _i12.Stroke():
        return 'Stroke';
      case _i13.StrokeRejectedMsg():
        return 'StrokeRejectedMsg';
      case _i14.StrokeSyncMsg():
        return 'StrokeSyncMsg';
      case _i15.StrokeUndoMsg():
        return 'StrokeUndoMsg';
      case _i16.TargetImage():
        return 'TargetImage';
    }
    className = _i2.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod.$className';
    }
    className = _i3.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_idp.$className';
    }
    className = _i4.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'FinalCanvasMsg') {
      return deserialize<_i5.FinalCanvasMsg>(data['data']);
    }
    if (dataClassName == 'GameEndFutureCallFinalizeRoomModel') {
      return deserialize<_i6.GameEndFutureCallFinalizeRoomModel>(data['data']);
    }
    if (dataClassName == 'GameStateChangeMsg') {
      return deserialize<_i7.GameStateChangeMsg>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_i8.Greeting>(data['data']);
    }
    if (dataClassName == 'Player') {
      return deserialize<_i9.Player>(data['data']);
    }
    if (dataClassName == 'Room') {
      return deserialize<_i10.Room>(data['data']);
    }
    if (dataClassName == 'RoomSubscribeMsg') {
      return deserialize<_i11.RoomSubscribeMsg>(data['data']);
    }
    if (dataClassName == 'Stroke') {
      return deserialize<_i12.Stroke>(data['data']);
    }
    if (dataClassName == 'StrokeRejectedMsg') {
      return deserialize<_i13.StrokeRejectedMsg>(data['data']);
    }
    if (dataClassName == 'StrokeSyncMsg') {
      return deserialize<_i14.StrokeSyncMsg>(data['data']);
    }
    if (dataClassName == 'StrokeUndoMsg') {
      return deserialize<_i15.StrokeUndoMsg>(data['data']);
    }
    if (dataClassName == 'TargetImage') {
      return deserialize<_i16.TargetImage>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _i2.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _i3.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i4.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i3.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _i4.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    switch (t) {
      case _i9.Player:
        return _i9.Player.t;
      case _i10.Room:
        return _i10.Room.t;
      case _i12.Stroke:
        return _i12.Stroke.t;
      case _i16.TargetImage:
        return _i16.TargetImage.t;
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'draw_together_serverpod';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _i3.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i4.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
