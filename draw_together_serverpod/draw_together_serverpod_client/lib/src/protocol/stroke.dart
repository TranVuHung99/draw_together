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
import 'package:draw_together_serverpod_client/src/protocol/protocol.dart'
    as _i2;

abstract class Stroke implements _i1.SerializableModel {
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

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
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
