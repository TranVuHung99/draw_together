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

abstract class RoomSubscribeMsg implements _i1.SerializableModel {
  RoomSubscribeMsg._({required this.roomId});

  factory RoomSubscribeMsg({required int roomId}) = _RoomSubscribeMsgImpl;

  factory RoomSubscribeMsg.fromJson(Map<String, dynamic> jsonSerialization) {
    return RoomSubscribeMsg(roomId: jsonSerialization['roomId'] as int);
  }

  int roomId;

  /// Returns a shallow copy of this [RoomSubscribeMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  RoomSubscribeMsg copyWith({int? roomId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RoomSubscribeMsg',
      'roomId': roomId,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _RoomSubscribeMsgImpl extends RoomSubscribeMsg {
  _RoomSubscribeMsgImpl({required int roomId}) : super._(roomId: roomId);

  /// Returns a shallow copy of this [RoomSubscribeMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  RoomSubscribeMsg copyWith({int? roomId}) {
    return RoomSubscribeMsg(roomId: roomId ?? this.roomId);
  }
}
