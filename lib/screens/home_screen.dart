import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的音乐'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('播放器'),
            onTap: () => context.go(AppRoutes.player),
          ),
          // 更多功能将在这里添加
        ],
      ),
    );
  }
}
