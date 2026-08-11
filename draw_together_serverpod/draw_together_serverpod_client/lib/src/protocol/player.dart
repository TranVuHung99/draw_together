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

abstract class Player implements _i1.SerializableModel {
  Player._({
    this.id,
    required this.roomId,
    required this.name,
    this.colorInfo,
    this.regionX,
    this.regionY,
    this.regionWidth,
    this.regionHeight,
  });

  factory Player({
    int? id,
    required int roomId,
    required String name,
    String? colorInfo,
    double? regionX,
    double? regionY,
    double? regionWidth,
    double? regionHeight,
  }) = _PlayerImpl;

  factory Player.fromJson(Map<String, dynamic> jsonSerialization) {
    return Player(
      id: jsonSerialization['id'] as int?,
      roomId: jsonSerialization['roomId'] as int,
      name: jsonSerialization['name'] as String,
      colorInfo: jsonSerialization['colorInfo'] as String?,
      regionX: (jsonSerialization['regionX'] as num?)?.toDouble(),
      regionY: (jsonSerialization['regionY'] as num?)?.toDouble(),
      regionWidth: (jsonSerialization['regionWidth'] as num?)?.toDouble(),
      regionHeight: (jsonSerialization['regionHeight'] as num?)?.toDouble(),
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int roomId;

  String name;

  String? colorInfo;

  double? regionX;

  double? regionY;

  double? regionWidth;

  double? regionHeight;

  /// Returns a shallow copy of this [Player]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Player copyWith({
    int? id,
    int? roomId,
    String? name,
    String? colorInfo,
    double? regionX,
    double? regionY,
    double? regionWidth,
    double? regionHeight,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Player',
      if (id != null) 'id': id,
      'roomId': roomId,
      'name': name,
      if (colorInfo != null) 'colorInfo': colorInfo,
      if (regionX != null) 'regionX': regionX,
      if (regionY != null) 'regionY': regionY,
      if (regionWidth != null) 'regionWidth': regionWidth,
      if (regionHeight != null) 'regionHeight': regionHeight,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _PlayerImpl extends Player {
  _PlayerImpl({
    int? id,
    required int roomId,
    required String name,
    String? colorInfo,
    double? regionX,
    double? regionY,
    double? regionWidth,
    double? regionHeight,
  }) : super._(
         id: id,
         roomId: roomId,
         name: name,
         colorInfo: colorInfo,
         regionX: regionX,
         regionY: regionY,
         regionWidth: regionWidth,
         regionHeight: regionHeight,
       );

  /// Returns a shallow copy of this [Player]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Player copyWith({
    Object? id = _Undefined,
    int? roomId,
    String? name,
    Object? colorInfo = _Undefined,
    Object? regionX = _Undefined,
    Object? regionY = _Undefined,
    Object? regionWidth = _Undefined,
    Object? regionHeight = _Undefined,
  }) {
    return Player(
      id: id is int? ? id : this.id,
      roomId: roomId ?? this.roomId,
      name: name ?? this.name,
      colorInfo: colorInfo is String? ? colorInfo : this.colorInfo,
      regionX: regionX is double? ? regionX : this.regionX,
      regionY: regionY is double? ? regionY : this.regionY,
      regionWidth: regionWidth is double? ? regionWidth : this.regionWidth,
      regionHeight: regionHeight is double? ? regionHeight : this.regionHeight,
    );
  }
}
