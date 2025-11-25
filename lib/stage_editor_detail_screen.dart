import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'game_model.dart';
import 'game_painter.dart';
import 'game_screen.dart';

class StageEditorDetailScreen extends StatefulWidget {
  final String? stageId;
  final List<String>? initialStageData;

  const StageEditorDetailScreen({
    super.key,
    this.stageId,
    this.initialStageData,
  });

  @override
  State<StageEditorDetailScreen> createState() =>
      _StageEditorDetailScreenState();
}

class _StageEditorDetailScreenState extends State<StageEditorDetailScreen> {
  late GameModel _gameModel;
  int _selectedPaletteIndex = 0;
  bool _isSaving = false;
  int? _lastPaintedX;
  int? _lastPaintedY;
  bool _hasBeenCleared = false;

  final List<Map<String, dynamic>> _paletteItems = [
    {'label': 'Wall', 'color': GamePainter.colorWall, 'type': 'wall'},
    {
      'label': 'Red',
      'color': GamePainter.jellyColors[JellyColor.red],
      'type': 'jelly',
      'jellyColor': JellyColor.red,
    },
    {
      'label': 'Blue',
      'color': GamePainter.jellyColors[JellyColor.blue],
      'type': 'jelly',
      'jellyColor': JellyColor.blue,
    },
    {
      'label': 'Yellow',
      'color': GamePainter.jellyColors[JellyColor.yellow],
      'type': 'jelly',
      'jellyColor': JellyColor.yellow,
    },
    {
      'label': 'Purple',
      'color': GamePainter.jellyColors[JellyColor.purple],
      'type': 'jelly',
      'jellyColor': JellyColor.purple,
    },
    {'label': 'Eraser', 'color': Colors.white, 'type': 'eraser'},
  ];

  @override
  void initState() {
    super.initState();
    _gameModel = GameModel();
    if (widget.initialStageData != null) {
      _gameModel.loadLevelFromData(widget.initialStageData!);
      _hasBeenCleared = true; // Already uploaded stages are considered cleared
    } else {
      _clearStage();
    }
  }

  void _clearStage() {
    _gameModel.walls = List.generate(gridH, (_) => List.filled(gridW, false));
    _gameModel.jellies = [];

    for (int y = 0; y < gridH; y++) {
      for (int x = 0; x < gridW; x++) {
        if (x == 0 || x == gridW - 1 || y == 0 || y == gridH - 1) {
          _gameModel.walls[y][x] = true;
        }
      }
    }
    _hasBeenCleared = false;
    setState(() {});
  }

  List<String> _convertStageToData() {
    List<String> stageData = [];

    for (int y = 0; y < gridH; y++) {
      String row = '';
      for (int x = 0; x < gridW; x++) {
        if (_gameModel.walls[y][x]) {
          row += '1';
        } else {
          final jelly = _gameModel.jellies.firstWhere(
            (j) => j.x == x && j.y == y,
            orElse: () => Jelly(x: -1, y: -1, color: JellyColor.red, id: -1),
          );
          if (jelly.id != -1) {
            row += jelly.color.value.toString();
          } else {
            row += '0';
          }
        }
      }
      stageData.add(row);
    }

    return stageData;
  }

  Future<void> _testPlay() async {
    final stageData = _convertStageToData();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GameScreen(stageData: stageData)),
    );

    if (result == true) {
      setState(() {
        _hasBeenCleared = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('テストプレイクリア!アップロードできます')));
      }
    }
  }

  Future<void> _saveStage() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('ログインが必要です');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final username = userDoc.data()?['username'] ?? '名無し';
      final stageData = _convertStageToData();

      if (widget.stageId != null) {
        // Update existing stage
        await FirebaseFirestore.instance
            .collection('stages')
            .doc(widget.stageId)
            .update({'stageData': stageData});
      } else {
        // Create new stage
        await FirebaseFirestore.instance.collection('stages').add({
          'stageData': stageData,
          'authorId': user.uid,
          'authorName': username,
          'createdAt': FieldValue.serverTimestamp(),
          'isPublic': true,
          'likeCount': 0,
          'clearCount': 0,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.stageId != null ? 'ステージを更新しました' : 'ステージをアップロードしました',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _handlePanStart(DragStartDetails details, Size size) {
    _lastPaintedX = null;
    _lastPaintedY = null;
    _handlePanUpdate(
      DragUpdateDetails(
        globalPosition: details.globalPosition,
        localPosition: details.localPosition,
      ),
      size,
    );
  }

  void _handlePanUpdate(DragUpdateDetails details, Size size) {
    final tileSize = size.width / gridW;
    final dx = details.localPosition.dx;
    final dy = details.localPosition.dy;

    final x = (dx / tileSize).floor();
    final y = (dy / tileSize).floor();

    if (x >= 0 && x < gridW && y >= 0 && y < gridH) {
      if (x == 0 || x == gridW - 1 || y == 0 || y == gridH - 1) return;

      if (_lastPaintedX != x || _lastPaintedY != y) {
        _updateCell(x, y);
        _lastPaintedX = x;
        _lastPaintedY = y;
      }
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    _lastPaintedX = null;
    _lastPaintedY = null;
  }

  void _updateCell(int x, int y) {
    setState(() {
      final item = _paletteItems[_selectedPaletteIndex];
      final type = item['type'];

      _gameModel.walls[y][x] = false;
      _gameModel.jellies.removeWhere((j) => j.x == x && j.y == y);

      if (type == 'wall') {
        _gameModel.walls[y][x] = true;
      } else if (type == 'jelly') {
        final color = item['jellyColor'] as JellyColor;
        _gameModel.jellies.add(
          Jelly(x: x, y: y, color: color, id: _gameModel.jellies.length),
        );
      }

      _gameModel.updateJellyGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2c3e50),
      appBar: AppBar(
        title: Text(
          widget.stageId != null ? 'ステージ編集' : '新規ステージ',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else if (_hasBeenCleared)
            IconButton(
              icon: const Icon(Icons.upload),
              onPressed: _saveStage,
              tooltip: widget.stageId != null ? 'Update Stage' : 'Upload Stage',
            )
          else
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: _testPlay,
              tooltip: 'Test Play',
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _clearStage,
            tooltip: 'Clear Stage',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.biggest;
                    double side = size.width < size.height
                        ? size.width
                        : size.height;

                    return GestureDetector(
                      onPanStart: (details) =>
                          _handlePanStart(details, Size(side, side)),
                      onPanUpdate: (details) =>
                          _handlePanUpdate(details, Size(side, side)),
                      onPanEnd: _handlePanEnd,
                      child: SizedBox(
                        width: side,
                        height: side,
                        child: CustomPaint(
                          painter: GamePainter(
                            game: _gameModel,
                            tileSize: side / gridW,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          Container(
            height: 120,
            color: Colors.black.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _paletteItems.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final item = _paletteItems[index];
                final isSelected = _selectedPaletteIndex == index;

                return GestureDetector(
                  onTap: () => setState(() => _selectedPaletteIndex = index),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: item['color'],
                            borderRadius: BorderRadius.circular(8),
                            border: item['type'] == 'eraser'
                                ? Border.all(color: Colors.grey)
                                : null,
                          ),
                          child: item['type'] == 'eraser'
                              ? const Icon(Icons.close, color: Colors.red)
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item['label'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
