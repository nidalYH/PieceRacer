import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/puzzle_piece.dart';
import '../utils/puzzle_path_generator.dart';

class PuzzleGenerator {
  static EdgeType _randomEdge(Random random) =>
      random.nextBool() ? EdgeType.tab : EdgeType.blank;

  static EdgeType _opposite(EdgeType e) {
    if (e == EdgeType.tab) return EdgeType.blank;
    if (e == EdgeType.blank) return EdgeType.tab;
    return EdgeType.flat;
  }

  /// Divides an image into [rows] x [cols] pieces.
  /// [boardSize] is the physical size of the canvas where the puzzle is played.
  /// [scatterArea] is where the pieces will be initially randomly placed.
  /// [seed] — when non-null, produces a deterministic puzzle (same edges + scatter).
  ///          Online modes MUST pass the seed from the room document.
  static List<PuzzlePiece> generatePieces({
    required ui.Image image,
    required int rows,
    required int cols,
    required Size boardSize,
    required Rect scatterArea,
    int? seed,
  }) {
    final List<PuzzlePiece> flatPiecesList = [];
    final double pieceSourceWidth = image.width / cols;
    final double pieceSourceHeight = image.height / rows;

    final double pieceDisplayWidth = boardSize.width / cols;
    final double pieceDisplayHeight = boardSize.height / rows;

    final random = seed != null ? Random(seed) : Random();
    
    // We will build a 2D array of pieces to easily link edges
    final pieces = List.generate(
      rows,
      (_) => List<PuzzlePiece?>.filled(cols, null),
    );
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        EdgeType top;
        EdgeType left;

        // Outer borders are flat. Shared borders are opposite of previous pieces.
        if (r == 0) {
          top = EdgeType.flat;
        } else {
          final above = pieces[r - 1][c]!;
          top = _opposite(above.edges.bottom);
        }

        if (c == 0) {
          left = EdgeType.flat;
        } else {
          final leftPiece = pieces[r][c - 1]!;
          left = _opposite(leftPiece.edges.right);
        }

        // Generate right and bottom. If at the edge, it's flat.
        EdgeType right = (c == cols - 1) ? EdgeType.flat : _randomEdge(random);
        EdgeType bottom = (r == rows - 1) ? EdgeType.flat : _randomEdge(random);

        final edges = PuzzleEdges(
          top: top,
          right: right,
          bottom: bottom,
          left: left,
        );

        final sourceRect = Rect.fromLTWH(
          c * pieceSourceWidth,
          r * pieceSourceHeight,
          pieceSourceWidth,
          pieceSourceHeight,
        );

        final correctPosition = Offset(
          c * pieceDisplayWidth,
          r * pieceDisplayHeight,
        );

        // Random initial position within the scatter area
        final double rx = scatterArea.left + random.nextDouble() * (scatterArea.width - pieceDisplayWidth);
        final double ry = scatterArea.top + random.nextDouble() * (scatterArea.height - pieceDisplayHeight);
        final currentPosition = Offset(rx, ry);

        final Size pieceDisplaySize = Size(pieceDisplayWidth, pieceDisplayHeight);
        final Path customPath = PuzzlePathGenerator.generate(
          size: pieceDisplaySize,
          edges: edges,
        );

        final newPiece = PuzzlePiece(
          id: r * cols + c,
          sourceRect: sourceRect,
          correctPosition: correctPosition,
          currentPosition: currentPosition,
          rotation: 0.0,
          edges: edges,
          customPath: customPath,
        );

        pieces[r][c] = newPiece;
        flatPiecesList.add(newPiece);
      }
    }

    return flatPiecesList;
  }
}
