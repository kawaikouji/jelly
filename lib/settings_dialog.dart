import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  String? _currentName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    setState(() => _isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        user = userCredential.user;
      }

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists &&
            doc.data() != null &&
            doc.data()!.containsKey('username')) {
          setState(() {
            _currentName = doc.data()!['username'];
            _nameController.text = _currentName ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        user = userCredential.user;
      }

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'username': name,
        }, SetOptions(merge: true));

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('名前を保存しました')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error saving name: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openOtherApps() async {
    final String url;
    if (Platform.isAndroid) {
      url = 'https://play.google.com/store/apps/dev?id=6874100708327409187';
    } else if (Platform.isIOS) {
      url = 'https://apps.apple.com/jp/developer/kouji-kawai/id170448691';
    } else {
      // その他のプラットフォームの場合はAndroidのURLを使用
      url = 'https://play.google.com/store/apps/dev?id=6874100708327409187';
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('URLを開けませんでした')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('設定'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('名前の変更'),
            onTap: () {
              _showNameChangeDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('ライセンス'),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'くっつけゼリー',
                applicationVersion: '1.0.0',
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text('他のアプリを見る'),
            onTap: () {
              _openOtherApps();
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('バージョン'),
            subtitle: const Text('1.0.0'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  void _showNameChangeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('名前の変更'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '新しい名前',
            hintText: '名前を入力してください',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close input dialog
              _saveName();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
