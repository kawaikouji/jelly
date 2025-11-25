import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_model.dart';
import 'game_painter.dart';

class GameScreen extends StatefulWidget {
  final int? initialLevelIndex;
  final List<String>? stageData;
  final String? stageId;

  const GameScreen({
    super.key,
    this.initialLevelIndex,
    this.stageData,
    this.stageId,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameModel _game = GameModel();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.stageData != null) {
      _game.loadLevelFromData(widget.stageData!);
    } else {
      _game.loadLevel(widget.initialLevelIndex ?? 0);
    }
    _game.addListener(_onGameUpdate);
    // Request focus for keyboard input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _game.removeListener(_onGameUpdate);
    _focusNode.dispose();
    super.dispose();
  }

  void _onGameUpdate() {
    setState(() {});
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (_game.isLevelCleared) {
        _game.nextLevel();
        return;
      }
      if (_game.isGameClear) {
        // Maybe restart or just do nothing
        return;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyR) {
        _game.resetLevel();
        return;
      }
      int dx = 0;
      int dy = 0;
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) dy = -1;
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) dy = 1;
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) dx = -1;
      if (event.logicalKey == LogicalKeyboardKey.arrowRight) dx = 1;
      if (dx != 0 || dy != 0) {
        _game.move(dx, dy);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate tile size based on screen size
    final screenSize = MediaQuery.of(context).size;
    final double availableWidth = screenSize.width * 0.9;
    final double availableHeight = screenSize.height * 0.7;
    final double tileSize = (availableWidth < availableHeight)
        ? availableWidth / gridW
        : availableHeight / gridH;
    return Scaffold(
      backgroundColor: const Color(0xFF2c3e50),
      body: KeyboardListener(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if (_game.isLevelCleared || _game.isGameClear) return;
            if (details.primaryVelocity! > 0) {
              _game.move(1, 0); // Right
            } else if (details.primaryVelocity! < 0) {
              _game.move(-1, 0); // Left
            }
          },
          onVerticalDragEnd: (details) {
            if (_game.isLevelCleared || _game.isGameClear) return;
            if (details.primaryVelocity! > 0) {
              _game.move(0, 1); // Down
            } else if (details.primaryVelocity! < 0) {
              _game.move(0, -1); // Up
            }
          },
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'くっつけゼリー 4Colors',
                      style: TextStyle(
                        color: Color(0xFFecf0f1),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Back Button
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white70,
                        ),
                        label: const Text(
                          'Menu',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(const Color(0xFFe74c3c), 'Red'),
                        const SizedBox(width: 15),
                        _buildLegendItem(const Color(0xFF3498db), 'Blue'),
                        const SizedBox(width: 15),
                        _buildLegendItem(const Color(0xFFf1c40f), 'Yellow'),
                        const SizedBox(width: 15),
                        _buildLegendItem(const Color(0xFF9b59b6), 'Purple'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CustomPaint(
                          size: Size(gridW * tileSize, gridH * tileSize),
                          painter: GamePainter(game: _game, tileSize: tileSize),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '移動: フリック',
                          style: TextStyle(
                            color: Color(0xFFf1c40f),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            _game.resetLevel();
                            // Keep focus for keyboard if used
                            _focusNode.requestFocus();
                          },
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('リセット'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFe74c3c),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_game.isLevelCleared)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'STAGE CLEAR!',
                          style: TextStyle(
                            color: Color(0xFF2ecc71),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: () {
                            _game.nextLevel();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Next Level'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_game.isGameClear)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'CONGRATULATIONS!',
                          style: TextStyle(
                            color: Color(0xFFf1c40f),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '全ステージクリア！',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFecf0f1), fontSize: 12),
        ),
      ],
    );
  }
}
