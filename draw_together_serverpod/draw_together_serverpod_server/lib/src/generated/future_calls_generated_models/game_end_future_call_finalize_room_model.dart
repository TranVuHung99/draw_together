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

abstract class GameEndFutureCallFinalizeRoomModel
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  GameEndFutureCallFinalizeRoomModel._({required this.roomId});

  factory GameEndFutureCallFinalizeRoomModel({required int roomId}) =
      _GameEndFutureCallFinalizeRoomModelImpl;

  factory GameEndFutureCallFinalizeRoomModel.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return GameEndFutureCallFinalizeRoomModel(
      roomId: jsonSerialization['roomId'] as int,
    );
  }

  int roomId;

  /// Returns a shallow copy of this [GameEndFutureCallFinalizeRoomModel]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  GameEndFutureCallFinalizeRoomModel copyWith({int? roomId});
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'GameEndFutureCallFinalizeRoomModel',
      'roomId': roomId,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {};
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _GameEndFutureCallFinalizeRoomModelImpl
    extends GameEndFutureCallFinalizeRoomModel {
  _GameEndFutureCallFinalizeRoomModelImpl({required int roomId})
    : super._(roomId: roomId);

  /// Returns a shallow copy of this [GameEndFutureCallFinalizeRoomModel]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  GameEndFutureCallFinalizeRoomModel copyWith({int? roomId}) {
    return GameEndFutureCallFinalizeRoomModel(roomId: roomId ?? this.roomId);
  }
}
