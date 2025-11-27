import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'radial_lines_painter.dart';
import 'dart:math' as math;

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(_rotationController);
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text(
            'ランキング',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Color(0xFF3498db),
            tabs: [
              Tab(text: '投稿数'),
              Tab(text: 'クリア数'),
            ],
          ),
        ),
        body: Stack(
          children: [
            // 背景グラデーション
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2c3e50),
                    Color(0xFF34495e),
                    Color(0xFF2c3e50),
                  ],
                ),
              ),
            ),

            // 回転する効果線
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: RadialLinesPainter(
                    rotation: _rotationAnimation.value,
                  ),
                  child: Container(),
                );
              },
            ),

            // ロゴ（背景として表示）
            Positioned(
              top: MediaQuery.of(context).padding.top + kToolbarHeight + 50,
              left: 0,
              right: 0,
              child: Image.asset(
                'assets/images/title_logo.png',
                height: 200,
                fit: BoxFit.contain,
              ),
            ),

            // 暗いオーバーレイ（UIの視認性向上）
            Container(color: Colors.black.withValues(alpha: 0.5)),

            // ランキングリスト
            const SafeArea(
              child: TabBarView(
                children: [
                  _RankingList(orderBy: 'postCount'),
                  _RankingList(orderBy: 'totalClearCount'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  final String orderBy;

  const _RankingList({required this.orderBy});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy(orderBy, descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'エラーが発生しました',
              style: const TextStyle(color: Colors.white),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(
            child: Text('データがありません', style: TextStyle(color: Colors.white70)),
          );
        }

        return ListView.builder(
          itemCount: docs.length,
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final username = data['username'] as String? ?? '名無し';
            final count = data[orderBy] as int? ?? 0;
            final rank = index + 1;

            Color rankColor;
            if (rank == 1) {
              rankColor = const Color(0xFFf1c40f); // Gold
            } else if (rank == 2) {
              rankColor = const Color(0xFFbdc3c7); // Silver
            } else if (rank == 3) {
              rankColor = const Color(0xFFe67e22); // Bronze
            } else {
              rankColor = Colors.white;
            }

            return Card(
              color: Colors.black.withValues(alpha: 0.3), // 背景に合わせて少し暗く
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rank <= 3
                        ? rankColor.withValues(alpha: 0.2)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: rankColor, width: 2),
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      color: rankColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                title: Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
