import 'dart:math';
import 'package:flutter/foundation.dart';

// Constants
const int gridW = 15;
const int gridH = 15;

// Colors matching the HTML version
// 2: Red, 3: Blue, 4: Yellow, 5: Purple
enum JellyColor {
  red(2),
  blue(3),
  yellow(4),
  purple(5);

  final int value;
  const JellyColor(this.value);

  static JellyColor? fromValue(int value) {
    return JellyColor.values.firstWhere(
      (e) => e.value == value,
      orElse: () => JellyColor.red,
    );
  }
}

class Jelly {
  int x;
  int y;
  final JellyColor color;
  int id;
  int tempId; // For grouping algorithm

  Jelly({
    required this.x,
    required this.y,
    required this.color,
    required this.id,
    this.tempId = 0,
  });
}

class GameModel extends ChangeNotifier {
  List<List<bool>> walls = [];
  List<Jelly> jellies = [];
  int currentLevelIdx = 0;
  bool isLevelCleared = false;
  bool isGameClear = false;

  // Level Data (Ported from HTML)
  static const List<List<String>> levels = [
    // Level 1: Red & Blue Separation
    [
      "111111111111111",
      "100000000000001",
      "102000000000301",
      "100000000000001",
      "100000000000001",
      "100000111000001",
      "100000101000001",
      "100000000000001",
      "103000101000201",
      "100000111000001",
      "100000000000001",
      "100000000000001",
      "102000000000301",
      "100000000000001",
      "111111111111111",
    ],
    // Level 2: Blocking
    [
      "111111111111111",
      "100001000000001",
      "102001002000001",
      "100001000000001",
      "100001111100001",
      "100000030000001",
      "100000000000001",
      "111001111100111",
      "100000000000001",
      "100000030000001",
      "100001111100001",
      "100001000000001",
      "102001002000001",
      "100001000000001",
      "111111111111111",
    ],
    // Level 3: 4 Colors
    [
      "111111111111111",
      "120000000000041",
      "100000000000001",
      "100300000005001",
      "100001111100001",
      "100001000100001",
      "100000000000001",
      "100500101002001",
      "100000000000001",
      "100001000100001",
      "100001111100001",
      "100400000003001",
      "100000000000001",
      "120000000000041",
      "111111111111111",
    ],
    // Level 4: The Swap
    [
      "111111111111111",
      "100000010000001",
      "102220010033301",
      "102020000030301",
      "100000000000001",
      "111110010011111",
      "100000010000001",
      "100400000005001",
      "100000010000001",
      "111110010011111",
      "100000000000001",
      "105050000040401",
      "105550010044401",
      "100000010000001",
      "111111111111111",
    ],
  ];

  GameModel() {
    loadLevel(0);
  }

  void loadLevel(int index) {
    if (index >= levels.length) {
      isGameClear = true;
      notifyListeners();
      return;
    }

    currentLevelIdx = index;
    isLevelCleared = false;
    isGameClear = false;
    walls = [];
    jellies = [];

    final levelData = levels[index];

    for (int y = 0; y < gridH; y++) {
      List<bool> wallRow = [];
      for (int x = 0; x < gridW; x++) {
        // levelData is list of strings, so we access row string then char index
        if (x >= levelData[y].length) {
          wallRow.add(false);
          continue;
        }

        String charStr = levelData[y][x];
        int char = int.tryParse(charStr) ?? 0;

        if (char == 1) {
          wallRow.add(true);
        } else {
          wallRow.add(false);
          if (char >= 2 && char <= 5) {
            jellies.add(
              Jelly(
                x: x,
                y: y,
                color: JellyColor.fromValue(char)!,
                id: jellies.length, // Unique ID initially
              ),
            );
          }
        }
      }
      walls.add(wallRow);
    }

    updateJellyGroups();
    notifyListeners();
  }

  void nextLevel() {
    loadLevel(currentLevelIdx + 1);
  }

  void resetLevel() {
    loadLevel(currentLevelIdx);
  }

  void move(int dx, int dy) {
    if (isLevelCleared || isGameClear) return;

    // 1. Grouping logic
    // Identify which jellies move together (same ID = same physical body)
    Map<int, List<Jelly>> groups = {};
    for (var j in jellies) {
      if (!groups.containsKey(j.id)) groups[j.id] = [];
      groups[j.id]!.add(j);
    }

    List<int> groupIds = groups.keys.toList();
    Map<int, bool> canMove = {for (var id in groupIds) id: true};

    // 2. Collision Resolution (Iterative)
    bool changed = true;
    while (changed) {
      changed = false;

      for (var id in groupIds) {
        if (canMove[id] == false) continue; // Already stopped

        final groupCells = groups[id]!;
        bool blocked = false;

        for (var cell in groupCells) {
          final nx = cell.x + dx;
          final ny = cell.y + dy;

          // Wall collision
          if (nx < 0 || nx >= gridW || ny < 0 || ny >= gridH || walls[ny][nx]) {
            blocked = true;
            break;
          }

          // Jelly collision
          final hitJelly = getJellyAt(nx, ny);
          if (hitJelly != null && hitJelly.id != id) {
            // If hitting another group that is stopped, we stop.
            if (canMove[hitJelly.id] == false) {
              blocked = true;
              break;
            }
          }
        }

        if (blocked) {
          canMove[id] = false;
          changed = true; // State changed, re-evaluate others
        }
      }
    }

    // 3. Apply Movement
    bool moved = false;
    for (var j in jellies) {
      if (canMove[j.id] == true) {
        j.x += dx;
        j.y += dy;
        moved = true;
      }
    }

    // 4. Merge & Check Win
    if (moved) {
      updateJellyGroups();
      checkWin();
      notifyListeners();
    }
  }

  Jelly? getJellyAt(int x, int y) {
    try {
      return jellies.firstWhere((j) => j.x == x && j.y == y);
    } catch (e) {
      return null;
    }
  }

  void updateJellyGroups() {
    // Reset IDs to unique temporarily
    for (int i = 0; i < jellies.length; i++) {
      jellies[i].tempId = i;
    }

    bool changed = true;
    while (changed) {
      changed = false;
      for (int i = 0; i < jellies.length; i++) {
        for (int j = i + 1; j < jellies.length; j++) {
          final j1 = jellies[i];
          final j2 = jellies[j];

          // Only merge if SAME COLOR
          if (j1.color != j2.color) continue;

          // If adjacent
          if ((j1.x - j2.x).abs() + (j1.y - j2.y).abs() == 1) {
            if (j1.tempId != j2.tempId) {
              final minId = min(j1.tempId, j2.tempId);
              final maxId = max(j1.tempId, j2.tempId);

              for (var jel in jellies) {
                if (jel.tempId == maxId) jel.tempId = minId;
              }
              changed = true;
            }
          }
        }
      }
    }

    // Apply back
    for (var j in jellies) {
      j.id = j.tempId;
    }
  }

  void checkWin() {
    // Find all unique colors present on board
    final colorsOnBoard = jellies.map((j) => j.color).toSet();

    bool allCleared = true;

    for (var color in colorsOnBoard) {
      // Get all jellies of this color
      final sameColorJellies = jellies.where((j) => j.color == color).toList();
      // Count unique group IDs for this color
      final uniqueGroupIds = sameColorJellies.map((j) => j.id).toSet();

      // If more than 1 group exists for this color, not cleared yet
      if (uniqueGroupIds.length > 1) {
        allCleared = false;
        break;
      }
    }

    if (allCleared) {
      isLevelCleared = true;
    }
  }
}
