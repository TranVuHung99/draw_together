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

abstract class StrokeUndoMsg
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  StrokeUndoMsg._({
    required this.roomId,
    required this.playerId,
    required this.strokeId,
  });

  factory StrokeUndoMsg({
    required int roomId,
    required int playerId,
    required String strokeId,
  }) = _StrokeUndoMsgImpl;

  factory StrokeUndoMsg.fromJson(Map<String, dynamic> jsonSerialization) {
    return StrokeUndoMsg(
      roomId: jsonSerialization['roomId'] as int,
      playerId: jsonSerialization['playerId'] as int,
      strokeId: jsonSerialization['strokeId'] as String,
    );
  }

  int roomId;

  int playerId;

  String strokeId;

  /// Returns a shallow copy of this [StrokeUndoMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  StrokeUndoMsg copyWith({
    int? roomId,
    int? playerId,
    String? strokeId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'StrokeUndoMsg',
      'roomId': roomId,
      'playerId': playerId,
      'strokeId': strokeId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'StrokeUndoMsg',
      'roomId': roomId,
      'playerId': playerId,
      'strokeId': strokeId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _StrokeUndoMsgImpl extends StrokeUndoMsg {
  _StrokeUndoMsgImpl({
    required int roomId,
    required int playerId,
    required String strokeId,
  }) : super._(
         roomId: roomId,
         playerId: playerId,
         strokeId: strokeId,
       );

  /// Returns a shallow copy of this [StrokeUndoMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  StrokeUndoMsg copyWith({
    int? roomId,
    int? playerId,
    String? strokeId,
  }) {
    return StrokeUndoMsg(
      roomId: roomId ?? this.roomId,
      playerId: playerId ?? this.playerId,
      strokeId: strokeId ?? this.strokeId,
    );
  }
}
