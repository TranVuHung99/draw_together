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
  GameEndFutureCallFinalizeRoomModel._({
    required this.roomId,
    required this.ignoreDeadline,
  });

  factory GameEndFutureCallFinalizeRoomModel({
    required int roomId,
    required bool ignoreDeadline,
  }) = _GameEndFutureCallFinalizeRoomModelImpl;

  factory GameEndFutureCallFinalizeRoomModel.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return GameEndFutureCallFinalizeRoomModel(
      roomId: jsonSerialization['roomId'] as int,
      ignoreDeadline: jsonSerialization['ignoreDeadline'] as bool,
    );
  }

  int roomId;

  bool ignoreDeadline;

  /// Returns a shallow copy of this [GameEndFutureCallFinalizeRoomModel]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  GameEndFutureCallFinalizeRoomModel copyWith({
    int? roomId,
    bool? ignoreDeadline,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'GameEndFutureCallFinalizeRoomModel',
      'roomId': roomId,
      'ignoreDeadline': ignoreDeadline,
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
  _GameEndFutureCallFinalizeRoomModelImpl({
    required int roomId,
    required bool ignoreDeadline,
  }) : super._(
         roomId: roomId,
         ignoreDeadline: ignoreDeadline,
       );

  /// Returns a shallow copy of this [GameEndFutureCallFinalizeRoomModel]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  GameEndFutureCallFinalizeRoomModel copyWith({
    int? roomId,
    bool? ignoreDeadline,
  }) {
    return GameEndFutureCallFinalizeRoomModel(
      roomId: roomId ?? this.roomId,
      ignoreDeadline: ignoreDeadline ?? this.ignoreDeadline,
    );
  }
}
