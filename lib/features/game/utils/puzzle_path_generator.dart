import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/puzzle_piece.dart';

class PuzzlePathGenerator {
  /// Generates an authentic jigsaw piece path based on the given dimensions and edges configuration.
  static Path generate({
    required Size size,
    required PuzzleEdges edges,
  }) {
    final Path path = Path();
    final double w = size.width;
    final double h = size.height;

    // We start at (0, 0)
    path.moveTo(0, 0);

    // TOP EDGE: (0,0) to (w,0) => Angle 0
    _addEdge(path, w, 0.0, Offset.zero, edges.top);

    // RIGHT EDGE: (w,0) to (w,h) => Angle pi/2
    _addEdge(path, h, math.pi / 2, Offset(w, 0), edges.right);

    // BOTTOM EDGE: (w,h) to (0,h) => Angle pi
    _addEdge(path, w, math.pi, Offset(w, h), edges.bottom);

    // LEFT EDGE: (0,h) to (0,0) => Angle -pi/2
    _addEdge(path, h, -math.pi / 2, Offset(0, h), edges.left);

    path.close();
    return path;
  }

  static void _addEdge(Path mainPath, double length, double angle, Offset translation, EdgeType type) {
    if (type == EdgeType.flat) {
      // Just a straight line to the end of this segment
      final double endX = translation.dx + length * math.cos(angle);
      final double endY = translation.dy + length * math.sin(angle);
      mainPath.lineTo(endX, endY);
      return;
    }

    final double sign = type == EdgeType.tab ? -1.0 : 1.0;
    final Path edgePath = _getRealisticEdgePath(length, sign);

    // Create standard transformation matrix
    final Matrix4 matrix = Matrix4.identity()
      ..translate(translation.dx, translation.dy)
      ..rotateZ(angle);

    // extendWithPath securely appends it avoiding disconnections
    mainPath.extendWithPath(edgePath, Offset.zero, matrix4: matrix.storage);
  }

  /// Generates a realistic $\Omega$ shaped jigsaw edge pointing outwards (negative Y).
  static Path _getRealisticEdgePath(double length, double sign) {
    final Path path = Path();
    path.moveTo(0, 0);

    final double mid = length / 2;
    // Tab dimensions ratio
    final double tw = length * 0.18; // Base width of the neck
    final double th = length * 0.22 * sign; // Height of the tab

    // Flat to neck start
    path.lineTo(mid - tw, 0);

    // Lower Neck (Starts curving inward slightly, then outward)
    path.cubicTo(
      mid - tw * 0.2, 0, // cp1
      mid - tw * 0.8, th * 0.4, // cp2
      mid - tw * 1.1, th * 0.5, // end neck
    );

    // Bulb / Head
    path.cubicTo(
      mid - tw * 2.2, th * 1.2, // cp1 (overshoot left)
      mid + tw * 2.2, th * 1.2, // cp2 (overshoot right)
      mid + tw * 1.1, th * 0.5, // end head (symmetric to neck end)
    );

    // Return to Neck Base
    path.cubicTo(
      mid + tw * 0.8, th * 0.4, // cp1
      mid + tw * 0.2, 0, // cp2
      mid + tw, 0, // neck end
    );

    // Flat to end
    path.lineTo(length, 0);

    return path;
  }
}
