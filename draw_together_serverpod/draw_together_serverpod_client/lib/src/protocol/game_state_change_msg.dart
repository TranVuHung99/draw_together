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

abstract class GameStateChangeMsg implements _i1.SerializableModel {
  GameStateChangeMsg._({
    required this.roomId,
    required this.status,
    this.endTime,
  });

  factory GameStateChangeMsg({
    required int roomId,
    required String status,
    DateTime? endTime,
  }) = _GameStateChangeMsgImpl;

  factory GameStateChangeMsg.fromJson(Map<String, dynamic> jsonSerialization) {
    return GameStateChangeMsg(
      roomId: jsonSerialization['roomId'] as int,
      status: jsonSerialization['status'] as String,
      endTime: jsonSerialization['endTime'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(jsonSerialization['endTime']),
    );
  }

  int roomId;

  String status;

  DateTime? endTime;

  /// Returns a shallow copy of this [GameStateChangeMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  GameStateChangeMsg copyWith({
    int? roomId,
    String? status,
    DateTime? endTime,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'GameStateChangeMsg',
      'roomId': roomId,
      'status': status,
      if (endTime != null) 'endTime': endTime?.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _GameStateChangeMsgImpl extends GameStateChangeMsg {
  _GameStateChangeMsgImpl({
    required int roomId,
    required String status,
    DateTime? endTime,
  }) : super._(
         roomId: roomId,
         status: status,
         endTime: endTime,
       );

  /// Returns a shallow copy of this [GameStateChangeMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  GameStateChangeMsg copyWith({
    int? roomId,
    String? status,
    Object? endTime = _Undefined,
  }) {
    return GameStateChangeMsg(
      roomId: roomId ?? this.roomId,
      status: status ?? this.status,
      endTime: endTime is DateTime? ? endTime : this.endTime,
    );
  }
}
