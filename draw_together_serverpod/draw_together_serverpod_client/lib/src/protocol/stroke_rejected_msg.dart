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

abstract class StrokeRejectedMsg implements _i1.SerializableModel {
  StrokeRejectedMsg._({
    required this.roomId,
    required this.playerId,
    required this.strokeId,
    required this.reason,
  });

  factory StrokeRejectedMsg({
    required int roomId,
    required int playerId,
    required String strokeId,
    required String reason,
  }) = _StrokeRejectedMsgImpl;

  factory StrokeRejectedMsg.fromJson(Map<String, dynamic> jsonSerialization) {
    return StrokeRejectedMsg(
      roomId: jsonSerialization['roomId'] as int,
      playerId: jsonSerialization['playerId'] as int,
      strokeId: jsonSerialization['strokeId'] as String,
      reason: jsonSerialization['reason'] as String,
    );
  }

  int roomId;

  int playerId;

  String strokeId;

  String reason;

  /// Returns a shallow copy of this [StrokeRejectedMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  StrokeRejectedMsg copyWith({
    int? roomId,
    int? playerId,
    String? strokeId,
    String? reason,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StrokeRejectedMsg',
      'roomId': roomId,
      'playerId': playerId,
      'strokeId': strokeId,
      'reason': reason,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _StrokeRejectedMsgImpl extends StrokeRejectedMsg {
  _StrokeRejectedMsgImpl({
    required int roomId,
    required int playerId,
    required String strokeId,
    required String reason,
  }) : super._(
         roomId: roomId,
         playerId: playerId,
         strokeId: strokeId,
         reason: reason,
       );

  /// Returns a shallow copy of this [StrokeRejectedMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  StrokeRejectedMsg copyWith({
    int? roomId,
    int? playerId,
    String? strokeId,
    String? reason,
  }) {
    return StrokeRejectedMsg(
      roomId: roomId ?? this.roomId,
      playerId: playerId ?? this.playerId,
      strokeId: strokeId ?? this.strokeId,
      reason: reason ?? this.reason,
    );
  }
}
