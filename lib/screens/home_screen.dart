import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/mini_player.dart';
import 'recommendation_screen.dart';
import 'search_screen.dart';
import 'playlist_screen.dart';
import 'profile_screen.dart';

/// 当前选中的底部导航索引
final currentTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  /// 构造函数
  HomeScreen({super.key});

  /// 定义底部导航项对应的页面列表
  final List<Widget> _pages = [
    /// 发现页面
    const RecommendationScreen(),

    /// 歌单页面
    const PlaylistScreen(),

    /// 搜索页面
    const SearchScreen(),

    /// 个人中心页面
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// 监听当前选中的底部导航索引状态
    final currentTab = ref.watch(currentTabProvider);

    /// 返回 Scaffold 作为页面基本结构
    return Scaffold(
      /// 使用 Stack 组件实现内容区域和底部迷你播放器的层叠显示
      body: Stack(
        children: [
          /// 主内容区域，使用 IndexedStack 根据当前选中的索引显示对应的页面
          IndexedStack(
            index: currentTab,
            children: _pages,
          ),

          /// 迷你播放器，使用 Positioned 固定在底部导航栏上方
          const Positioned(
            left: 0,
            right: 0,

            /// 距离底部一定距离，使其位于底部导航栏上方
            bottom: 5,
            child: MiniPlayer(),
          ),
        ],
      ),

      /// 底部导航栏
      bottomNavigationBar: BottomNavigationBar(
        /// 当前选中的索引
        currentIndex: currentTab,

        /// 底部导航项点击回调，更新当前选中的索引
        onTap: (index) => ref.read(currentTabProvider.notifier).state = index,

        /// 设置底部导航栏的类型为固定，显示所有标签
        type: BottomNavigationBarType.fixed,

        /// 选中时的颜色
        selectedItemColor: Theme.of(context).colorScheme.primary,

        /// 未选中时的颜色
        unselectedItemColor: Colors.grey,

        /// 底部导航项列表
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '发现',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.playlist_play),
            label: '歌单',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: '搜索',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
