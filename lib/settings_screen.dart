import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();
  String? _currentName;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  Future<void> _loadUserName() async {
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
    }
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

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
    }
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
              Navigator.pop(context);
              _saveName();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
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
    return Scaffold(
      backgroundColor: const Color(0xFF2c3e50),
      appBar: AppBar(
        title: const Text(
          '設定',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF34495e),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person, color: Colors.white),
            title: const Text('名前の変更', style: TextStyle(color: Colors.white)),
            subtitle: _currentName != null
                ? Text(
                    '現在の名前: $_currentName',
                    style: const TextStyle(color: Colors.white70),
                  )
                : null,
            onTap: _showNameChangeDialog,
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.description, color: Colors.white),
            title: const Text('ライセンス', style: TextStyle(color: Colors.white)),
            onTap: () {
              showLicensePage(
                context: context,
                applicationName: 'くっつけゼリー',
                applicationVersion: _version,
              );
            },
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.apps, color: Colors.white),
            title: const Text(
              '他のアプリを見る',
              style: TextStyle(color: Colors.white),
            ),
            onTap: _openOtherApps,
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.info, color: Colors.white),
            title: const Text('バージョン', style: TextStyle(color: Colors.white)),
            subtitle: Text(
              _version,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
