import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../models/puzzle_piece.dart';
import '../services/puzzle_generator.dart';

class PuzzleBoard extends StatefulWidget {
  const PuzzleBoard({
    required this.image,
    required this.rows,
    required this.cols,
    required this.onPieceLocked,
    required this.onSolved,
    this.seed,
    super.key,
  });

  final ui.Image image;
  final int rows;
  final int cols;
  final void Function(int lockedCount, int total) onPieceLocked;
  final void Function() onSolved;
  final int? seed;

  @override
  State<PuzzleBoard> createState() => _PuzzleBoardState();
}

class _PuzzleBoardState extends State<PuzzleBoard> {
  List<PuzzlePiece> _pieces = [];
  bool _initialized = false;
  List<PuzzlePiece> _activeGroup = [];

  double _canvasWidth = 0;
  double _canvasHeight = 0;
  double _boardSize = 0;
  double _boardOffsetX = 0;
  double _boardOffsetY = 0;
  double _trayY = 0;

  void _initPieces(double canvasWidth, double canvasHeight) {
    if (_initialized) return;
    _initialized = true;

    _canvasWidth = canvasWidth;
    _canvasHeight = canvasHeight;

    final double maxBoardH = canvasHeight * 0.48;
    _boardSize = canvasWidth < maxBoardH ? canvasWidth : maxBoardH;
    _boardOffsetX = (canvasWidth - _boardSize) / 2;
    _boardOffsetY = 8;
    _trayY = _boardOffsetY + _boardSize + 20;
    final double trayHeight = canvasHeight - _trayY - 8;

    final scatterArea = Rect.fromLTWH(
      8, _trayY,
      canvasWidth - 16,
      trayHeight > 60 ? trayHeight : 100,
    );

    final generated = PuzzleGenerator.generatePieces(
      image: widget.image,
      rows: widget.rows,
      cols: widget.cols,
      boardSize: Size(_boardSize, _boardSize),
      scatterArea: scatterArea,
      seed: widget.seed,
    );

    // Offset correctPositions to match board placement on canvas
    for (final piece in generated) {
      piece.correctPosition = Offset(
        piece.correctPosition.dx + _boardOffsetX,
        piece.correctPosition.dy + _boardOffsetY,
      );
    }

    setState(() => _pieces = generated);
    
    // Notify parent of initial count
    final locked = _pieces.where((p) => p.isLocked).length;
    widget.onPieceLocked(locked, _pieces.length);
  }

  PuzzlePiece? _hitTest(Offset pos) {
    final double pw = _boardSize / widget.cols;
    final double ph = _boardSize / widget.rows;
    for (int i = _pieces.length - 1; i >= 0; i--) {
      final p = _pieces[i];
      if (p.isLocked) continue;
      if (Rect.fromLTWH(p.currentPosition.dx, p.currentPosition.dy, pw, ph)
          .inflate(10)
          .contains(pos)) return p;
    }
    return null;
  }

  void _onPanStart(DragStartDetails d) {
    if (!_initialized || _pieces.isEmpty) return;
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(d.globalPosition);
    final piece = _hitTest(local);
    if (piece == null) return;

    setState(() {
      _activeGroup = piece.groupId != null
          ? _pieces.where((p) => p.groupId == piece.groupId).toList()
          : [piece];
      for (final p in _activeGroup) {
        _pieces.remove(p);
        _pieces.add(p);
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_activeGroup.isEmpty) return;
    setState(() {
      for (final p in _activeGroup) {
        p.updatePosition(d.delta);
      }
    });
  }

  void _onPanEnd(DragEndDetails d) {
    if (_activeGroup.isEmpty || !_initialized) return;

    final double pw = _boardSize / widget.cols;
    final snapDist = pw * 0.35;
    bool anyLocked = false;

    for (final p in _activeGroup) {
      final was = p.isLocked;
      p.checkLock(snapDist);
      if (!was && p.isLocked) anyLocked = true;
    }

    if (anyLocked) {
      for (final p in _activeGroup) {
        if (!p.isLocked) {
          p.currentPosition = p.correctPosition;
          p.rotation = 0.0;
          p.isLocked = true;
        }
      }
      HapticFeedback.lightImpact();
      final locked = _pieces.where((p) => p.isLocked).length;
      widget.onPieceLocked(locked, _pieces.length);
      if (_pieces.every((p) => p.isLocked)) {
        widget.onSolved();
      }
    }

    setState(() => _activeGroup = []);
  }

  void _onDoubleTapDown(TapDownDetails d) {
    if (!_initialized || _pieces.isEmpty) return;
    final box = context.findRenderObject() as RenderBox;
    final local = box.globalToLocal(d.globalPosition);
    final piece = _hitTest(local);
    if (piece == null) return;
    setState(() => piece.rotate());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      if (!_initialized && w > 0 && h > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _initPieces(w, h));
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTapDown: _onDoubleTapDown,
        onDoubleTap: () {},
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: CustomPaint(
          size: Size(w, h),
          painter: _PuzzlePainter(
            image: widget.image,
            pieces: _pieces,
            rows: widget.rows,
            cols: widget.cols,
            boardSize: _boardSize,
            boardOffsetX: _boardOffsetX,
            boardOffsetY: _boardOffsetY,
            trayY: _trayY,
            canvasWidth: w,
          ),
        ),
      );
    });
  }
}

class _PuzzlePainter extends CustomPainter {
  _PuzzlePainter({
    required this.image,
    required this.pieces,
    required this.rows,
    required this.cols,
    required this.boardSize,
    required this.boardOffsetX,
    required this.boardOffsetY,
    required this.trayY,
    required this.canvasWidth,
  });

  final ui.Image image;
  final List<PuzzlePiece> pieces;
  final int rows, cols;
  final double boardSize, boardOffsetX, boardOffsetY, trayY, canvasWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final double pw = boardSize / cols;
    final double ph = boardSize / rows;

    // === BOARD ZONE ===
    final boardRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(boardOffsetX, boardOffsetY, boardSize, boardSize),
      const Radius.circular(16),
    );
    canvas.drawRRect(boardRect, Paint()..color = const Color(0xFF1A1F3A));

    // Ghost guide
    canvas.save();
    canvas.clipRRect(boardRect);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(boardOffsetX, boardOffsetY, boardSize, boardSize),
      Paint()..color = Colors.white.withOpacity(0.08),
    );
    canvas.restore();

    // Grid
    final gp = Paint()..color = Colors.white.withOpacity(0.08)..strokeWidth = 0.8;
    for (int r = 1; r < rows; r++) {
      final y = boardOffsetY + r * ph;
      canvas.drawLine(Offset(boardOffsetX, y), Offset(boardOffsetX + boardSize, y), gp);
    }
    for (int c = 1; c < cols; c++) {
      final x = boardOffsetX + c * pw;
      canvas.drawLine(Offset(x, boardOffsetY), Offset(x, boardOffsetY + boardSize), gp);
    }

    // Board border
    canvas.drawRRect(boardRect, Paint()
      ..color = AppColors.neonCyan.withOpacity(0.2)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);

    // Tray divider
    canvas.drawLine(
      Offset(20, trayY - 8), Offset(canvasWidth - 20, trayY - 8),
      Paint()..color = AppColors.neonCyan.withOpacity(0.15)..strokeWidth = 1,
    );
    final tp = TextPainter(
      text: TextSpan(text: '↑ Arrastra las piezas', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((canvasWidth - tp.width) / 2, trayY - 6));

    // === PIECES ===
    final Paint pp = Paint()..isAntiAlias = true;
    final double imgW = image.width.toDouble();
    final double imgH = image.height.toDouble();
    const double tabRatio = 0.25;

    for (final piece in pieces) {
      canvas.save();
      canvas.translate(
        piece.currentPosition.dx + pw / 2,
        piece.currentPosition.dy + ph / 2,
      );
      canvas.rotate(piece.rotation);
      canvas.translate(-pw / 2, -ph / 2);

      if (piece.customPath != null) {
        final double srcPadX = piece.sourceRect.width * tabRatio;
        final double srcPadY = piece.sourceRect.height * tabRatio;

        final srcL = (piece.sourceRect.left - srcPadX).clamp(0.0, imgW);
        final srcT = (piece.sourceRect.top - srcPadY).clamp(0.0, imgH);
        final srcR = (piece.sourceRect.right + srcPadX).clamp(0.0, imgW);
        final srcB = (piece.sourceRect.bottom + srcPadY).clamp(0.0, imgH);

        final scX = pw / piece.sourceRect.width;
        final scY = ph / piece.sourceRect.height;
        final dstL = -(piece.sourceRect.left - srcL) * scX;
        final dstT = -(piece.sourceRect.top - srcT) * scY;
        final dstR = pw + (srcR - piece.sourceRect.right) * scX;
        final dstB = ph + (srcB - piece.sourceRect.bottom) * scY;

        // Shadow
        if (!piece.isLocked) {
          canvas.drawPath(piece.customPath!.shift(const Offset(3, 3)), Paint()
            ..color = Colors.black54..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        }

        // Jigsaw clip + expanded image
        canvas.save();
        canvas.clipPath(piece.customPath!);
        canvas.drawImageRect(
          image,
          Rect.fromLTRB(srcL, srcT, srcR, srcB),
          Rect.fromLTRB(dstL, dstT, dstR, dstB),
          pp,
        );
        canvas.restore();

        // Border
        canvas.drawPath(piece.customPath!, Paint()
          ..color = piece.isLocked ? AppColors.neonGreen.withOpacity(0.6) : AppColors.neonCyan.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = piece.isLocked ? 2 : 1.2);
      } else {
        final dst = Rect.fromLTWH(0, 0, pw, ph);
        canvas.drawImageRect(image, piece.sourceRect, dst, pp);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PuzzlePainter oldDelegate) => true;
}
