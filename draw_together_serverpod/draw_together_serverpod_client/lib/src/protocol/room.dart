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

abstract class Room implements _i1.SerializableModel {
  Room._({
    this.id,
    required this.roomCode,
    required this.hostId,
    required this.status,
    required this.canvasWidth,
    required this.canvasHeight,
    this.endTime,
  });

  factory Room({
    int? id,
    required String roomCode,
    required int hostId,
    required String status,
    required double canvasWidth,
    required double canvasHeight,
    DateTime? endTime,
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
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  String roomCode;

  int hostId;

  String status;

  double canvasWidth;

  double canvasHeight;

  DateTime? endTime;

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
    };
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
  }) : super._(
         id: id,
         roomCode: roomCode,
         hostId: hostId,
         status: status,
         canvasWidth: canvasWidth,
         canvasHeight: canvasHeight,
         endTime: endTime,
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
  }) {
    return Room(
      id: id is int? ? id : this.id,
      roomCode: roomCode ?? this.roomCode,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      endTime: endTime is DateTime? ? endTime : this.endTime,
    );
  }
}
