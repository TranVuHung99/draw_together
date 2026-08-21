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
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'final_canvas_msg.dart' as _i2;
import 'game_state_change_msg.dart' as _i3;
import 'greetings/greeting.dart' as _i4;
import 'player.dart' as _i5;
import 'room.dart' as _i6;
import 'room_subscribe_msg.dart' as _i7;
import 'stroke.dart' as _i8;
import 'stroke_sync_msg.dart' as _i9;
import 'stroke_undo_msg.dart' as _i10;
import 'package:draw_together_serverpod_client/src/protocol/player.dart'
    as _i11;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _i12;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i13;
export 'final_canvas_msg.dart';
export 'game_state_change_msg.dart';
export 'greetings/greeting.dart';
export 'player.dart';
export 'room.dart';
export 'room_subscribe_msg.dart';
export 'stroke.dart';
export 'stroke_sync_msg.dart';
export 'stroke_undo_msg.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

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

    if (t == _i2.FinalCanvasMsg) {
      return _i2.FinalCanvasMsg.fromJson(data) as T;
    }
    if (t == _i3.GameStateChangeMsg) {
      return _i3.GameStateChangeMsg.fromJson(data) as T;
    }
    if (t == _i4.Greeting) {
      return _i4.Greeting.fromJson(data) as T;
    }
    if (t == _i5.Player) {
      return _i5.Player.fromJson(data) as T;
    }
    if (t == _i6.Room) {
      return _i6.Room.fromJson(data) as T;
    }
    if (t == _i7.RoomSubscribeMsg) {
      return _i7.RoomSubscribeMsg.fromJson(data) as T;
    }
    if (t == _i8.Stroke) {
      return _i8.Stroke.fromJson(data) as T;
    }
    if (t == _i9.StrokeSyncMsg) {
      return _i9.StrokeSyncMsg.fromJson(data) as T;
    }
    if (t == _i10.StrokeUndoMsg) {
      return _i10.StrokeUndoMsg.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.FinalCanvasMsg?>()) {
      return (data != null ? _i2.FinalCanvasMsg.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.GameStateChangeMsg?>()) {
      return (data != null ? _i3.GameStateChangeMsg.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.Greeting?>()) {
      return (data != null ? _i4.Greeting.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.Player?>()) {
      return (data != null ? _i5.Player.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.Room?>()) {
      return (data != null ? _i6.Room.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.RoomSubscribeMsg?>()) {
      return (data != null ? _i7.RoomSubscribeMsg.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.Stroke?>()) {
      return (data != null ? _i8.Stroke.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.StrokeSyncMsg?>()) {
      return (data != null ? _i9.StrokeSyncMsg.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.StrokeUndoMsg?>()) {
      return (data != null ? _i10.StrokeUndoMsg.fromJson(data) : null) as T;
    }
    if (t == List<double>) {
      return (data as List).map((e) => deserialize<double>(e)).toList() as T;
    }
    if (t == List<_i11.Player>) {
      return (data as List).map((e) => deserialize<_i11.Player>(e)).toList()
          as T;
    }
    try {
      return _i12.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i13.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.FinalCanvasMsg => 'FinalCanvasMsg',
      _i3.GameStateChangeMsg => 'GameStateChangeMsg',
      _i4.Greeting => 'Greeting',
      _i5.Player => 'Player',
      _i6.Room => 'Room',
      _i7.RoomSubscribeMsg => 'RoomSubscribeMsg',
      _i8.Stroke => 'Stroke',
      _i9.StrokeSyncMsg => 'StrokeSyncMsg',
      _i10.StrokeUndoMsg => 'StrokeUndoMsg',
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
      case _i2.FinalCanvasMsg():
        return 'FinalCanvasMsg';
      case _i3.GameStateChangeMsg():
        return 'GameStateChangeMsg';
      case _i4.Greeting():
        return 'Greeting';
      case _i5.Player():
        return 'Player';
      case _i6.Room():
        return 'Room';
      case _i7.RoomSubscribeMsg():
        return 'RoomSubscribeMsg';
      case _i8.Stroke():
        return 'Stroke';
      case _i9.StrokeSyncMsg():
        return 'StrokeSyncMsg';
      case _i10.StrokeUndoMsg():
        return 'StrokeUndoMsg';
    }
    className = _i12.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_idp.$className';
    }
    className = _i13.Protocol().getClassNameForObject(data);
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
      return deserialize<_i2.FinalCanvasMsg>(data['data']);
    }
    if (dataClassName == 'GameStateChangeMsg') {
      return deserialize<_i3.GameStateChangeMsg>(data['data']);
    }
    if (dataClassName == 'Greeting') {
      return deserialize<_i4.Greeting>(data['data']);
    }
    if (dataClassName == 'Player') {
      return deserialize<_i5.Player>(data['data']);
    }
    if (dataClassName == 'Room') {
      return deserialize<_i6.Room>(data['data']);
    }
    if (dataClassName == 'RoomSubscribeMsg') {
      return deserialize<_i7.RoomSubscribeMsg>(data['data']);
    }
    if (dataClassName == 'Stroke') {
      return deserialize<_i8.Stroke>(data['data']);
    }
    if (dataClassName == 'StrokeSyncMsg') {
      return deserialize<_i9.StrokeSyncMsg>(data['data']);
    }
    if (dataClassName == 'StrokeUndoMsg') {
      return deserialize<_i10.StrokeUndoMsg>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _i12.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i13.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

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
      return _i12.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i13.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
