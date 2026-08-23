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
import 'dart:typed_data' as _i2;

abstract class TargetImage implements _i1.SerializableModel {
  TargetImage._({
    this.id,
    required this.roomId,
    this.playerId,
    required this.bytes,
    required this.mimeType,
    required this.width,
    required this.height,
  });

  factory TargetImage({
    int? id,
    required int roomId,
    int? playerId,
    required _i2.ByteData bytes,
    required String mimeType,
    required int width,
    required int height,
  }) = _TargetImageImpl;

  factory TargetImage.fromJson(Map<String, dynamic> jsonSerialization) {
    return TargetImage(
      id: jsonSerialization['id'] as int?,
      roomId: jsonSerialization['roomId'] as int,
      playerId: jsonSerialization['playerId'] as int?,
      bytes: _i1.ByteDataJsonExtension.fromJson(jsonSerialization['bytes']),
      mimeType: jsonSerialization['mimeType'] as String,
      width: jsonSerialization['width'] as int,
      height: jsonSerialization['height'] as int,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int roomId;

  int? playerId;

  _i2.ByteData bytes;

  String mimeType;

  int width;

  int height;

  /// Returns a shallow copy of this [TargetImage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  TargetImage copyWith({
    int? id,
    int? roomId,
    int? playerId,
    _i2.ByteData? bytes,
    String? mimeType,
    int? width,
    int? height,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'TargetImage',
      if (id != null) 'id': id,
      'roomId': roomId,
      if (playerId != null) 'playerId': playerId,
      'bytes': bytes.toJson(),
      'mimeType': mimeType,
      'width': width,
      'height': height,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _TargetImageImpl extends TargetImage {
  _TargetImageImpl({
    int? id,
    required int roomId,
    int? playerId,
    required _i2.ByteData bytes,
    required String mimeType,
    required int width,
    required int height,
  }) : super._(
         id: id,
         roomId: roomId,
         playerId: playerId,
         bytes: bytes,
         mimeType: mimeType,
         width: width,
         height: height,
       );

  /// Returns a shallow copy of this [TargetImage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  TargetImage copyWith({
    Object? id = _Undefined,
    int? roomId,
    Object? playerId = _Undefined,
    _i2.ByteData? bytes,
    String? mimeType,
    int? width,
    int? height,
  }) {
    return TargetImage(
      id: id is int? ? id : this.id,
      roomId: roomId ?? this.roomId,
      playerId: playerId is int? ? playerId : this.playerId,
      bytes: bytes ?? this.bytes.clone(),
      mimeType: mimeType ?? this.mimeType,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}
