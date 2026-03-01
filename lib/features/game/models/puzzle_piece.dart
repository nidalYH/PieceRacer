import 'dart:math' show pi;
import 'package:flutter/material.dart';

enum EdgeType {
  flat,
  tab,
  blank,
}

class PuzzleEdges {
  PuzzleEdges({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  final EdgeType top;
  final EdgeType right;
  final EdgeType bottom;
  final EdgeType left;
}

class PuzzlePiece {
  PuzzlePiece({
    required this.id,
    required this.sourceRect,
    required this.correctPosition,
    required this.currentPosition,
    required this.edges,
    this.rotation = 0.0,
    this.isLocked = false,
    this.groupId,
    this.customPath,
  });

  final int id;
  final Rect sourceRect;
  Offset correctPosition;
  Offset currentPosition;
  double rotation;
  bool isLocked;
  String? groupId;
  final PuzzleEdges edges;
  final Path? customPath;

  void updatePosition(Offset delta) {
    if (!isLocked) {
      currentPosition += delta;
    }
  }

  void rotate() {
    if (!isLocked) {
      rotation += pi / 2;
      if (rotation >= 2 * pi) {
        rotation = 0.0;
      }
    }
  }

  void checkLock(double snapDistance) {
    if (isLocked) return;

    final distance = (currentPosition - correctPosition).distance;
    final bool correctRotation = (rotation % (2 * pi)).abs() < 0.01;
    
    if (distance <= snapDistance && correctRotation) {
      currentPosition = correctPosition;
      rotation = 0.0;
      isLocked = true;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'x': currentPosition.dx,
      'y': currentPosition.dy,
      'rotation': rotation,
      'locked': isLocked,
      'groupId': groupId,
    };
  }

  // fromMap without edges since edges/path are regenerated on load for now,
  // or they need to be serialized as well.
  factory PuzzlePiece.fromMap(Map<String, dynamic> map, Rect source, Offset correctPos, PuzzleEdges edges, Path? path) {
    return PuzzlePiece(
      id: map['id'] as int,
      sourceRect: source,
      correctPosition: correctPos,
      currentPosition: Offset(
        (map['x'] as num).toDouble(),
        (map['y'] as num).toDouble(),
      ),
      isLocked: map['locked'] as bool? ?? false,
      groupId: map['groupId'] as String?,
      edges: edges,
      customPath: path,
    );
  }
}
