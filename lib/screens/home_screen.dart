import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/widgets/mini_player.dart';
import 'recommendation_screen.dart';
import 'search_screen.dart';
import 'playlist_screen.dart';
import 'profile_screen.dart';
import '../salomon_bottom_bar.dart'; // 确保路径正确

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
          Positioned(
            left: 0,
            right: 0,

            /// 距离底部一定距离，使其位于底部导航栏上方
            bottom: kBottomNavigationBarHeight + 5, // 考虑导航栏高度
            child: MiniPlayer(),
          ),
        ],
      ),

      /// 底部导航栏 - 使用 SalomonBottomBar
      bottomNavigationBar: SalomonBottomBar(
        /// 当前选中的索引
        currentIndex: currentTab,

        /// 底部导航项点击回调，更新当前选中的索引
        onTap: (index) => ref.read(currentTabProvider.notifier).state = index,

        /// 底部导航项列表
        items: [
          SalomonBottomBarItem(
            icon: Icon(Icons.home),
            title: Text("发现"),
            // 你可以自定义选中颜色，或使用主题色
            selectedColor: Theme.of(context).colorScheme.primary,
            // unselectedColor: Colors.grey, // 可选：未选中颜色
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.playlist_play),
            title: Text("歌单"),
            selectedColor: Theme.of(context).colorScheme.primary,
            // unselectedColor: Colors.grey,
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.search),
            title: Text("搜索"),
            selectedColor: Theme.of(context).colorScheme.primary,
            // unselectedColor: Colors.grey,
          ),
          SalomonBottomBarItem(
            icon: Icon(Icons.person),
            title: Text("我的"),
            selectedColor: Theme.of(context).colorScheme.primary,
            // unselectedColor: Colors.grey,
          ),
        ],
      ),
    );
  }
}
