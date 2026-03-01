import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piece_racer/features/game/models/puzzle_piece.dart';
import 'package:piece_racer/features/game/services/puzzle_generator.dart';

Future<ui.Image> createDummyImage(int width, int height) async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Paint paint = Paint()..color = Colors.blue;
  canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);
  final ui.Picture picture = recorder.endRecording();
  return await picture.toImage(width, height);
}

void main() {
  group('PuzzleGenerator', () {
    late ui.Image dummyImage;

    setUpAll(() async {
      dummyImage = await createDummyImage(300, 300);
    });

    test('generates correct number of pieces based on grid size', () {
      final pieces = PuzzleGenerator.generatePieces(
        image: dummyImage,
        rows: 3,
        cols: 4,
        boardSize: const Size(600, 600),
        scatterArea: const Rect.fromLTWH(0, 0, 600, 300),
      );

      expect(pieces.length, 12); // 3 * 4 = 12
    });

    test('sets outer edges to flat', () {
      final pieces = PuzzleGenerator.generatePieces(
        image: dummyImage,
        rows: 3,
        cols: 3,
        boardSize: const Size(300, 300),
        scatterArea: const Rect.fromLTWH(0, 0, 300, 150),
      );

      // Top row (0, 1, 2) should have top = flat
      expect(pieces[0].edges.top, EdgeType.flat);
      expect(pieces[1].edges.top, EdgeType.flat);
      expect(pieces[2].edges.top, EdgeType.flat);

      // Bottom row (6, 7, 8) should have bottom = flat
      expect(pieces[6].edges.bottom, EdgeType.flat);
      expect(pieces[7].edges.bottom, EdgeType.flat);
      expect(pieces[8].edges.bottom, EdgeType.flat);

      // Left column (0, 3, 6) should have left = flat
      expect(pieces[0].edges.left, EdgeType.flat);
      expect(pieces[3].edges.left, EdgeType.flat);
      expect(pieces[6].edges.left, EdgeType.flat);

      // Right column (2, 5, 8) should have right = flat
      expect(pieces[2].edges.right, EdgeType.flat);
      expect(pieces[5].edges.right, EdgeType.flat);
      expect(pieces[8].edges.right, EdgeType.flat);
    });

    test('adjacent pieces have corresponding complementary edges', () {
      final pieces = PuzzleGenerator.generatePieces(
        image: dummyImage,
        rows: 3,
        cols: 3,
        boardSize: const Size(300, 300),
        scatterArea: const Rect.fromLTWH(0, 0, 300, 300),
      );

      // Piece 0 and Piece 1 (horizontal neighbors)
      final p0 = pieces[0];
      final p1 = pieces[1];
      
      // If p0 right is tab, p1 left should be blank, and vice versa
      final bool rightComplementary = 
         (p0.edges.right == EdgeType.tab && p1.edges.left == EdgeType.blank) ||
         (p0.edges.right == EdgeType.blank && p1.edges.left == EdgeType.tab);
      expect(rightComplementary, true);

      // Piece 0 and Piece 3 (vertical neighbors)
      final p3 = pieces[3];
      final bool bottomComplementary = 
         (p0.edges.bottom == EdgeType.tab && p3.edges.top == EdgeType.blank) ||
         (p0.edges.bottom == EdgeType.blank && p3.edges.top == EdgeType.tab);
      expect(bottomComplementary, true);
    });
  });
}
