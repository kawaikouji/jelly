import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_model.dart';

/// One-time script to upload existing stage data to Firestore
/// Run this once to populate the database with the built-in levels
Future<void> uploadExistingStages() async {
  try {
    // Get current user (or use a system user)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('Error: No user logged in');
      return;
    }

    // Get username
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final username = userDoc.data()?['username'] ?? 'System';

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // Upload each level
    for (int i = 0; i < GameModel.levels.length; i++) {
      final levelData = GameModel.levels[i];

      // Create a document reference
      final docRef = firestore
          .collection('stages')
          .doc('official_level_${i + 1}');

      batch.set(docRef, {
        'stageData': levelData,
        'authorId': user.uid,
        'authorName': username,
        'createdAt': FieldValue.serverTimestamp(),
        'isPublic': true,
        'likeCount': 0,
        'clearCount': 0,
        'isOfficial': true, // Mark as official level
        'levelNumber': i + 1,
      });

      print('Prepared level ${i + 1} for upload');
    }

    // Commit the batch
    await batch.commit();
    print(
      'Successfully uploaded ${GameModel.levels.length} stages to Firestore!',
    );
  } catch (e) {
    print('Error uploading stages: $e');
  }
}
