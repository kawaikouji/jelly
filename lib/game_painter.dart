import 'package:flutter/material.dart';
import 'game_model.dart';

class GamePainter extends CustomPainter {
  final GameModel game;
  final double tileSize;

  GamePainter({required this.game, required this.tileSize});

  // Colors
  static const Color colorWall = Color(0xFF95a5a6);
  static const Color colorGridLine = Color(0xFF2c3e50);
  static const Map<JellyColor, Color> jellyColors = {
    JellyColor.red: Color(0xFFe74c3c),
    JellyColor.blue: Color(0xFF3498db),
    JellyColor.yellow: Color(0xFFf1c40f),
    JellyColor.purple: Color(0xFF9b59b6),
  };

  @override
  void paint(Canvas canvas, Size size) {
    // Draw Grid
    final paintGrid = Paint()
      ..color = colorGridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i <= gridW; i++) {
      canvas.drawLine(
        Offset(i * tileSize, 0),
        Offset(i * tileSize, gridH * tileSize),
        paintGrid,
      );
    }
    for (int i = 0; i <= gridH; i++) {
      canvas.drawLine(
        Offset(0, i * tileSize),
        Offset(gridW * tileSize, i * tileSize),
        paintGrid,
      );
    }

    // Draw Walls
    final paintWall = Paint()..color = colorWall;
    final paintWallBorder = Paint()
      ..color = const Color(0xFF7f8c8d)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int y = 0; y < gridH; y++) {
      for (int x = 0; x < gridW; x++) {
        if (y < game.walls.length &&
            x < game.walls[y].length &&
            game.walls[y][x]) {
          final rect = Rect.fromLTWH(
            x * tileSize,
            y * tileSize,
            tileSize,
            tileSize,
          );
          canvas.drawRect(rect, paintWall);
          canvas.drawRect(rect, paintWallBorder);
        }
      }
    }

    // Draw Jellies
    for (var j in game.jellies) {
      final x = j.x * tileSize;
      final y = j.y * tileSize;
      final color = jellyColors[j.color] ?? Colors.grey;

      // Connection check
      final sameGroup = game.jellies
          .where((other) => other.id == j.id)
          .toList();
      final up = sameGroup.any((o) => o.x == j.x && o.y == j.y - 1);
      final down = sameGroup.any((o) => o.x == j.x && o.y == j.y + 1);
      final left = sameGroup.any((o) => o.x == j.x - 1 && o.y == j.y);
      final right = sameGroup.any((o) => o.x == j.x + 1 && o.y == j.y);

      final paintJelly = Paint()..color = color;

      const double margin = 3.0;
      double tx = x + margin;
      double ty = y + margin;
      double tw = tileSize - margin * 2;
      double th = tileSize - margin * 2;

      if (left) {
        tx -= margin;
        tw += margin;
      }
      if (right) {
        tw += margin;
      }
      if (up) {
        ty -= margin;
        th += margin;
      }
      if (down) {
        th += margin;
      }

      // Corner radius logic
      const double rVal = 12.0;
      final r = Radius.circular(rVal);

      final tl = (up || left) ? Radius.zero : r;
      final tr = (up || right) ? Radius.zero : r;
      final bl = (down || left) ? Radius.zero : r;
      final br = (down || right) ? Radius.zero : r;

      // Draw jelly body
      final rect = Rect.fromLTWH(tx, ty, tw, th);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: tl,
        topRight: tr,
        bottomLeft: bl,
        bottomRight: br,
      );
      canvas.drawRRect(rrect, paintJelly);

      // Draw "Gloss" effect
      if (!up && !left) {
        final paintGloss = Paint()..color = Colors.white.withValues(alpha: 0.3);
        // Adjust gloss to fit rounded corner
        canvas.drawOval(Rect.fromLTWH(tx + 3, ty + 3, 8, 6), paintGloss);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Simple repaint for now, could optimize
  }
}
