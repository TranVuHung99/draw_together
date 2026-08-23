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

abstract class FinalCanvasMsg implements _i1.SerializableModel {
  FinalCanvasMsg._({
    required this.roomId,
    required this.svg,
  });

  factory FinalCanvasMsg({
    required int roomId,
    required String svg,
  }) = _FinalCanvasMsgImpl;

  factory FinalCanvasMsg.fromJson(Map<String, dynamic> jsonSerialization) {
    return FinalCanvasMsg(
      roomId: jsonSerialization['roomId'] as int,
      svg: jsonSerialization['svg'] as String,
    );
  }

  int roomId;

  String svg;

  /// Returns a shallow copy of this [FinalCanvasMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  FinalCanvasMsg copyWith({
    int? roomId,
    String? svg,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FinalCanvasMsg',
      'roomId': roomId,
      'svg': svg,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _FinalCanvasMsgImpl extends FinalCanvasMsg {
  _FinalCanvasMsgImpl({
    required int roomId,
    required String svg,
  }) : super._(
         roomId: roomId,
         svg: svg,
       );

  /// Returns a shallow copy of this [FinalCanvasMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  FinalCanvasMsg copyWith({
    int? roomId,
    String? svg,
  }) {
    return FinalCanvasMsg(
      roomId: roomId ?? this.roomId,
      svg: svg ?? this.svg,
    );
  }
}
