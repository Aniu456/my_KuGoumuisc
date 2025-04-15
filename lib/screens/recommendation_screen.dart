import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 发现音乐页面，展示轮播图、快捷功能、推荐歌单和最新音乐
class RecommendationScreen extends ConsumerWidget {
  /// 构造函数
  const RecommendationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发现音乐'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// 轮播图区域
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('轮播图区域'),
            ),
          ),
          const SizedBox(height: 24),

          /// 快捷功能入口
          _buildQuickActions(),
          const SizedBox(height: 24),

          /// 推荐歌单模块
          _buildSectionHeader('推荐歌单'),
          const SizedBox(height: 12),
          _buildPlaylistGrid(),
          const SizedBox(height: 24),

          /// 最新音乐模块
          _buildSectionHeader('最新音乐'),
          const SizedBox(height: 12),
          _buildSongList(),

          /// 底部播放器预留空间
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  /// 构建快捷功能区域
  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionItem(Icons.calendar_today, '每日推荐'),
        _buildActionItem(Icons.playlist_play, '歌单'),
        _buildActionItem(Icons.bar_chart, '排行榜'),
        _buildActionItem(Icons.radio, '电台'),
      ],
    );
  }

  /// 构建单个快捷功能项
  Widget _buildActionItem(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.red),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// 构建模块标题和“更多”按钮
  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextButton(
          onPressed: () {
            // TODO: 实现查看更多功能
          },
          child: const Text('更多'),
        ),
      ],
    );
  }

  /// 构建推荐歌单网格
  Widget _buildPlaylistGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.music_note, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '推荐歌单名称',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12),
            ),
          ],
        );
      },
    );
  }

  /// 构建最新音乐列表
  Widget _buildSongList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 50,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.all(Radius.circular(4)),
              ),
              child: const Icon(Icons.music_note, color: Colors.white),
            ),
          ),
          title: const Text('歌曲名称'),
          subtitle: const Text('歌手名称'),
          trailing: const Icon(Icons.more_vert),
        );
      },
    );
  }
}
