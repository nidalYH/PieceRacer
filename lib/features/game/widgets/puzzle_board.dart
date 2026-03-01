import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../models/puzzle_piece.dart';
import '../services/puzzle_generator.dart';
import '../services/realtime_sync_service.dart';

class PuzzleBoard extends StatefulWidget {
  const PuzzleBoard({
    required this.image,
    required this.rows,
    required this.cols,
    required this.onPieceLocked,
    required this.onSolved,
    this.seed,
    this.syncService,
    super.key,
  });

  final ui.Image image;
  final int rows;
  final int cols;
  final void Function(int lockedCount, int total) onPieceLocked;
  final void Function() onSolved;
  final int? seed;

  /// Optional — provided for 2v2 co-op mode. When non-null, piece movements
  /// are broadcast and remote updates are applied.
  final RealtimeSyncService? syncService;

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

  // Pieces currently held by remote players (show as "locked" visually)
  final Set<int> _remoteHeldPieces = {};

  @override
  void initState() {
    super.initState();
    _setupSyncCallbacks();
  }

  @override
  void dispose() {
    widget.syncService?.dispose();
    super.dispose();
  }

  void _setupSyncCallbacks() {
    final sync = widget.syncService;
    if (sync == null) return;

    sync.onPieceUpdated = (pieceId, data) {
      if (!mounted) return;
      final piece = _pieces.firstWhere((p) => p.id == pieceId, orElse: () => _pieces.first);
      if (piece.id != pieceId) return;

      setState(() {
        final x = (data['x'] as num?)?.toDouble();
        final y = (data['y'] as num?)?.toDouble();
        final locked = data['locked'] as bool? ?? false;
        final heldBy = data['heldBy'] as String?;

        if (x != null && y != null) {
          piece.currentPosition = Offset(x, y);
        }
        if (locked && !piece.isLocked) {
          piece.currentPosition = piece.correctPosition;
          piece.rotation = 0.0;
          piece.isLocked = true;
          HapticFeedback.lightImpact();

          final lockedCount = _pieces.where((p) => p.isLocked).length;
          widget.onPieceLocked(lockedCount, _pieces.length);
          if (_pieces.every((p) => p.isLocked)) {
            widget.onSolved();
          }
        }

        if (heldBy != null && heldBy != sync.uid) {
          _remoteHeldPieces.add(pieceId);
        } else {
          _remoteHeldPieces.remove(pieceId);
        }
      });
    };

    sync.startListening();
  }

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

    // For 2v2: initialize RTDB with piece positions (first player writes)
    _initSyncPiecePositions();
  }

  Future<void> _initSyncPiecePositions() async {
    final sync = widget.syncService;
    if (sync == null) return;

    // Check if pieces are already initialized by another player
    final existing = await sync.readPieceStates();
    if (existing != null && existing.isNotEmpty) {
      // Apply remote state
      setState(() {
        for (final entry in existing.entries) {
          final piece = _pieces.firstWhere((p) => p.id == entry.key, orElse: () => _pieces.first);
          if (piece.id != entry.key) continue;
          final data = entry.value;
          final x = (data['x'] as num?)?.toDouble();
          final y = (data['y'] as num?)?.toDouble();
          final locked = data['locked'] as bool? ?? false;
          if (x != null && y != null) {
            piece.currentPosition = Offset(x, y);
          }
          if (locked) {
            piece.currentPosition = piece.correctPosition;
            piece.rotation = 0.0;
            piece.isLocked = true;
          }
        }
      });
      return;
    }

    // First player: write initial positions
    final positions = <int, Map<String, double>>{};
    for (final piece in _pieces) {
      positions[piece.id] = {
        'x': piece.currentPosition.dx,
        'y': piece.currentPosition.dy,
      };
    }
    await sync.initializePieces(positions);
  }

  PuzzlePiece? _hitTest(Offset pos) {
    final double pw = _boardSize / widget.cols;
    final double ph = _boardSize / widget.rows;
    for (int i = _pieces.length - 1; i >= 0; i--) {
      final p = _pieces[i];
      if (p.isLocked) continue;
      // In co-op: skip pieces held by remote players
      if (_remoteHeldPieces.contains(p.id)) continue;
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

    // For co-op: try to claim the piece atomically
    final sync = widget.syncService;
    if (sync != null) {
      sync.tryGrabPiece(piece.id).then((claimed) {
        if (!claimed || !mounted) return;
        setState(() {
          _activeGroup = piece.groupId != null
              ? _pieces.where((p) => p.groupId == piece.groupId).toList()
              : [piece];
          for (final p in _activeGroup) {
            _pieces.remove(p);
            _pieces.add(p);
          }
        });
      });
      return;
    }

    // Normal (non-co-op) mode
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

    // Broadcast movement for co-op
    final sync = widget.syncService;
    if (sync != null) {
      for (final p in _activeGroup) {
        sync.movePiece(p.id, p.currentPosition.dx, p.currentPosition.dy);
      }
    }
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

    final sync = widget.syncService;

    if (anyLocked) {
      for (final p in _activeGroup) {
        if (!p.isLocked) {
          p.currentPosition = p.correctPosition;
          p.rotation = 0.0;
          p.isLocked = true;
        }
        // Broadcast lock to co-op
        sync?.lockPiece(p.id, p.correctPosition.dx, p.correctPosition.dy);
      }
      HapticFeedback.lightImpact();
      final locked = _pieces.where((p) => p.isLocked).length;
      widget.onPieceLocked(locked, _pieces.length);
      if (_pieces.every((p) => p.isLocked)) {
        widget.onSolved();
      }
    } else {
      // Release pieces in co-op
      for (final p in _activeGroup) {
        sync?.releasePiece(p.id, p.currentPosition.dx, p.currentPosition.dy);
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
            remoteHeldPieces: _remoteHeldPieces,
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
    required this.remoteHeldPieces,
  });

  final ui.Image image;
  final List<PuzzlePiece> pieces;
  final int rows, cols;
  final double boardSize, boardOffsetX, boardOffsetY, trayY, canvasWidth;
  final Set<int> remoteHeldPieces;

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
      final bool isRemoteHeld = remoteHeldPieces.contains(piece.id);

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
        // Dim pieces held by remote player
        final imgPaint = isRemoteHeld ? (Paint()..color = Colors.white.withOpacity(0.5)) : pp;
        canvas.drawImageRect(
          image,
          Rect.fromLTRB(srcL, srcT, srcR, srcB),
          Rect.fromLTRB(dstL, dstT, dstR, dstB),
          imgPaint,
        );
        canvas.restore();

        // Border — yellow for remote-held, green for locked, cyan for free
        final Color borderColor;
        if (isRemoteHeld) {
          borderColor = AppColors.neonOrange.withOpacity(0.7);
        } else if (piece.isLocked) {
          borderColor = AppColors.neonGreen.withOpacity(0.6);
        } else {
          borderColor = AppColors.neonCyan.withOpacity(0.35);
        }

        canvas.drawPath(piece.customPath!, Paint()
          ..color = borderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = piece.isLocked ? 2 : (isRemoteHeld ? 2 : 1.2));
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
