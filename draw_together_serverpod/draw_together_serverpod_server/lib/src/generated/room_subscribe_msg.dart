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

abstract class RoomSubscribeMsg
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  RoomSubscribeMsg._({
    required this.roomId,
    required this.playerId,
  });

  factory RoomSubscribeMsg({
    required int roomId,
    required int playerId,
  }) = _RoomSubscribeMsgImpl;

  factory RoomSubscribeMsg.fromJson(Map<String, dynamic> jsonSerialization) {
    return RoomSubscribeMsg(
      roomId: jsonSerialization['roomId'] as int,
      playerId: jsonSerialization['playerId'] as int,
    );
  }

  int roomId;

  int playerId;

  /// Returns a shallow copy of this [RoomSubscribeMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  RoomSubscribeMsg copyWith({
    int? roomId,
    int? playerId,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RoomSubscribeMsg',
      'roomId': roomId,
      'playerId': playerId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RoomSubscribeMsg',
      'roomId': roomId,
      'playerId': playerId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _RoomSubscribeMsgImpl extends RoomSubscribeMsg {
  _RoomSubscribeMsgImpl({
    required int roomId,
    required int playerId,
  }) : super._(
         roomId: roomId,
         playerId: playerId,
       );

  /// Returns a shallow copy of this [RoomSubscribeMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  RoomSubscribeMsg copyWith({
    int? roomId,
    int? playerId,
  }) {
    return RoomSubscribeMsg(
      roomId: roomId ?? this.roomId,
      playerId: playerId ?? this.playerId,
    );
  }
}
