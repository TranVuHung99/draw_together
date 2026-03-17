import 'package:flutter/material.dart';

class Stroke {
  final String id;
  final int playerId;
  final Path path;
  final Paint paint;
  final bool isEraser;

  Stroke({
    required this.id,
    required this.playerId,
    required this.path,
    required this.paint,
    required this.isEraser,
  });
}
