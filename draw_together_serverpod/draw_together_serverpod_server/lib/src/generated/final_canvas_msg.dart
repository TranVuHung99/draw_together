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

abstract class FinalCanvasMsg
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  FinalCanvasMsg._({
    required this.roomId,
    required this.base64Image,
  });

  factory FinalCanvasMsg({
    required int roomId,
    required String base64Image,
  }) = _FinalCanvasMsgImpl;

  factory FinalCanvasMsg.fromJson(Map<String, dynamic> jsonSerialization) {
    return FinalCanvasMsg(
      roomId: jsonSerialization['roomId'] as int,
      base64Image: jsonSerialization['base64Image'] as String,
    );
  }

  int roomId;

  String base64Image;

  /// Returns a shallow copy of this [FinalCanvasMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  FinalCanvasMsg copyWith({
    int? roomId,
    String? base64Image,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'FinalCanvasMsg',
      'roomId': roomId,
      'base64Image': base64Image,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'FinalCanvasMsg',
      'roomId': roomId,
      'base64Image': base64Image,
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
    required String base64Image,
  }) : super._(
         roomId: roomId,
         base64Image: base64Image,
       );

  /// Returns a shallow copy of this [FinalCanvasMsg]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  FinalCanvasMsg copyWith({
    int? roomId,
    String? base64Image,
  }) {
    return FinalCanvasMsg(
      roomId: roomId ?? this.roomId,
      base64Image: base64Image ?? this.base64Image,
    );
  }
}
