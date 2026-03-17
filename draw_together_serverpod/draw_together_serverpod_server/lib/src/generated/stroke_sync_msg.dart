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

abstract class StrokeSyncMsg
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  StrokeSyncMsg._({
    required this.roomId,
    required this.playerId,
    required this.strokeId,
    required this.action,
    required this.points,
    required this.colorInfo,
    required this.strokeWidth,
    required this.isEraser,
    required this.timestamp,
  });

  factory StrokeSyncMsg({
    required int roomId,
    required int playerId,
    required String strokeId,
    required String action,
    required List<double> points,
    required String colorInfo,
    required double strokeWidth,
    required bool isEraser,
    required DateTime timestamp,
  }) = _StrokeSyncMsgImpl;

  factory StrokeSyncMsg.fromJson(Map<String, dynamic> jsonSerialization) {
    return StrokeSyncMsg(
      roomId: jsonSerialization['roomId'] as int,
      playerId: jsonSerialization['playerId'] as int,
      strokeId: jsonSerialization['strokeId'] as String,
      action: jsonSerialization['action'] as String,
      points: _i2.Protocol().deserialize<List<double>>(
        jsonSerialization['points'],
      ),
      colorInfo: jsonSerialization['colorInfo'] as String,
      strokeWidth: (jsonSerialization['strokeWidth'] as num).toDouble(),
      isEraser: jsonSerialization['isEraser'] as bool,
      timestamp: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['timestamp'],
      ),
    );
  }

  int roomId;

  int playerId;

  String strokeId;

  String action;

  List<double> points;

  String colorInfo;

  double strokeWidth;

  bool isEraser;

  DateTime timestamp;

  /// Returns a shallow copy of this [StrokeSyncMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  StrokeSyncMsg copyWith({
    int? roomId,
    int? playerId,
    String? strokeId,
    String? action,
    List<double>? points,
    String? colorInfo,
    double? strokeWidth,
    bool? isEraser,
    DateTime? timestamp,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StrokeSyncMsg',
      'roomId': roomId,
      'playerId': playerId,
      'strokeId': strokeId,
      'action': action,
      'points': points.toJson(),
      'colorInfo': colorInfo,
      'strokeWidth': strokeWidth,
      'isEraser': isEraser,
      'timestamp': timestamp.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StrokeSyncMsg',
      'roomId': roomId,
      'playerId': playerId,
      'strokeId': strokeId,
      'action': action,
      'points': points.toJson(),
      'colorInfo': colorInfo,
      'strokeWidth': strokeWidth,
      'isEraser': isEraser,
      'timestamp': timestamp.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _StrokeSyncMsgImpl extends StrokeSyncMsg {
  _StrokeSyncMsgImpl({
    required int roomId,
    required int playerId,
    required String strokeId,
    required String action,
    required List<double> points,
    required String colorInfo,
    required double strokeWidth,
    required bool isEraser,
    required DateTime timestamp,
  }) : super._(
         roomId: roomId,
         playerId: playerId,
         strokeId: strokeId,
         action: action,
         points: points,
         colorInfo: colorInfo,
         strokeWidth: strokeWidth,
         isEraser: isEraser,
         timestamp: timestamp,
       );

  /// Returns a shallow copy of this [StrokeSyncMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  StrokeSyncMsg copyWith({
    int? roomId,
    int? playerId,
    String? strokeId,
    String? action,
    List<double>? points,
    String? colorInfo,
    double? strokeWidth,
    bool? isEraser,
    DateTime? timestamp,
  }) {
    return StrokeSyncMsg(
      roomId: roomId ?? this.roomId,
      playerId: playerId ?? this.playerId,
      strokeId: strokeId ?? this.strokeId,
      action: action ?? this.action,
      points: points ?? this.points.map((e0) => e0).toList(),
      colorInfo: colorInfo ?? this.colorInfo,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      isEraser: isEraser ?? this.isEraser,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
