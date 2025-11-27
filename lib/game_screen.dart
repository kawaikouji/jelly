import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _hasIncrementedClearCount = false;
  bool _hasLiked = false;

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
    if (_game.isLevelCleared &&
        !_hasIncrementedClearCount &&
        widget.stageId != null) {
      _incrementClearCount();
    }
    setState(() {});
  }

  Future<void> _incrementClearCount() async {
    _hasIncrementedClearCount = true;
    try {
      // Save to local storage and update user's total clear count if new clear
      final prefs = await SharedPreferences.getInstance();
      final clearedStages = prefs.getStringList('cleared_stages') ?? [];

      if (!clearedStages.contains(widget.stageId)) {
        clearedStages.add(widget.stageId!);
        await prefs.setStringList('cleared_stages', clearedStages);

        // Increment current user's total clear count
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'totalClearCount': FieldValue.increment(1)});
        }
      }

      // Increment stage clear count (global)
      final stageRef = FirebaseFirestore.instance
          .collection('stages')
          .doc(widget.stageId);

      await stageRef.update({'clearCount': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('Error incrementing clear count: $e');
    }
  }

  Future<void> _incrementLikeCount() async {
    if (_hasLiked || widget.stageId == null) return;

    setState(() {
      _hasLiked = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('stages')
          .doc(widget.stageId)
          .update({'likeCount': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('Error incrementing like count: $e');
      // Revert state if update fails
      if (mounted) {
        setState(() {
          _hasLiked = false;
        });
      }
    }
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF34495e),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
          tooltip: '戻る',
        ),
        elevation: 0,
      ),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (widget.stageData != null)
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context, true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2ecc71),
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('戻る'),
                              ),
                            if (widget.stageData != null &&
                                widget.stageId != null) ...[
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                onPressed: _hasLiked
                                    ? null
                                    : _incrementLikeCount,
                                icon: Icon(
                                  _hasLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.pink,
                                ),
                                label: Text(_hasLiked ? 'Liked!' : 'いいね'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.pink,
                                  disabledBackgroundColor: Colors.white,
                                  disabledForegroundColor: Colors.pink,
                                ),
                              ),
                            ] else if (widget.stageData == null)
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
