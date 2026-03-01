import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piece_racer/features/game/models/puzzle_piece.dart';
import 'package:piece_racer/features/game/utils/puzzle_path_generator.dart';

void main() {
  group('PuzzlePathGenerator', () {
    test('generate returns a closed path covering roughly the piece size', () {
      final Size pieceSize = const Size(100, 100);
      
      final edges = PuzzleEdges(
        top: EdgeType.flat,
        right: EdgeType.tab,
        bottom: EdgeType.blank,
        left: EdgeType.flat,
      );

      final Path path = PuzzlePathGenerator.generate(
        size: pieceSize,
        edges: edges,
      );

      // Path shouldn't be empty
      expect(path.computeMetrics().isNotEmpty, true);

      // Bounding box of the path should extend outwards on the right because of the 'tab'
      final Rect bounds = path.getBounds();
      
      // Top is flat
      expect(bounds.top >= 0, true);
      // Left is flat
      expect(bounds.left >= 0, true);
      
      // Right is tab, so it goes OUT (positive X direction, passing width 100)
      // Wait, is 'tab' outward? Our logic adds the tab geometry directly.
      // Indeed, Right edge is (length=100, angle=pi/2, translation=(100,0)).
      // The _getRealisticEdgePath with sign = -1 for tab draws OUTWARDS (negative Y relative to rotated frame).
      // Angle is pi/2. Rotated -Y becomes +X! So bounding box right should be strictly > 100
      expect(bounds.right > 100, true);

      // Bottom is blank, meaning it goes INWARDS. Bottom edge (w,h) to (0,h) angle=pi.
      // Blank is sign = 1 (INWARDS, positive Y in local frame).
      // Angle is pi. Local +Y rotated by pi is physical -Y. So it eats into the piece, meaning bounds.bottom should be ~100.
      expect(bounds.bottom <= 100.1, true); 
    });
  });
}
