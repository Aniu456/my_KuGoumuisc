import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_music_app/utils/image_utils.dart';
import '../bloc/auth/auth_bloc.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import '../services/audio_cache_manager.dart';
import '../models/playlist.dart';
import '../models/user.dart';
import 'music_list_screen.dart';
import 'recent_songs_section.dart';
import '../pages/search_page.dart';
import '../pages/local_songs_page.dart';
import 'package:provider/provider.dart';
import '../main.dart'; // 导入ThemeProvider类
import 'skeleton_loader.dart'; // 导入骨架屏组件

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with AutomaticKeepAliveClientMixin {
  // 常量定义
  static const double _borderRadius = 8.0;
  static const EdgeInsets _contentPadding = EdgeInsets.fromLTRB(10, 6, 10, 0);

  // 状态变量
  List<Playlist> _playlists = [];
  int _playlistCount = 0;
  Playlist _likedPlaylist = Playlist.empty();
  final bool _isPurchasedExpanded = false;
  int _localSongCount = 0;
  int _recentSongsCount = 0;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // 监听 AuthBloc 状态变化
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authBloc = context.read<AuthBloc>();
      // 检查初始状态
      if (authBloc.state is AuthAuthenticated) {
        _loadData(); // 只在初始化时加载一次
      }

      // 添加状态监听
      authBloc.stream.listen((state) {
        if (state is AuthAuthenticated) {
          if (_playlists.isEmpty) {
            _loadData(); // 只在歌单为空时加载数据
          }
        } else if (state is AuthUnauthenticated) {
          // 清除数据
          setState(() {
            _playlists = [];
            _playlistCount = 0;
            _likedPlaylist = Playlist.empty();
            _recentSongsCount = 0;
          });
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  // 统一的数据加载方法
  Future<void> _loadData() async {
    if (_isLoading) return; // 防止重复加载

    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadLocalSongCount(),
        _loadUserData(),
      ]);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 加载用户相关数据
  Future<void> _loadUserData() async {
    if (!mounted) return;
    try {
      final apiService = context.read<ApiService>();
      final userDetail = await apiService.getUserDetail();
      final vipInfo = await apiService.getUserVipDetail();
      final playlists = await apiService.getUserPlaylists(forceRefresh: true);
      final recentSongs = await apiService.getRecentSongs();

      if (mounted) {
        // 更新用户信息
        context.read<AuthBloc>().add(AuthUpdateUserInfo(
              userDetail: userDetail,
              vipInfo: vipInfo,
            ));

        // 更新歌单数据
        _updatePlaylistsData(playlists);

        // 更新最近播放数量
        setState(() {
          _recentSongsCount = recentSongs.songs.length;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('加载数据失败: $e');
      }
    }
  }

  // 刷新数据（用于下拉刷新）
  Future<void> _refreshFromServer() async {
    return _loadData();
  }

  // 加载本地歌曲数量
  Future<void> _loadLocalSongCount() async {
    try {
      final cacheManager = await AudioCacheManager.getInstance();
      final count = await cacheManager.getCachedCount();
      if (mounted) setState(() => _localSongCount = count);
    } catch (e) {
      print('加载本地歌曲数量失败: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // 更新歌单数据
  void _updatePlaylistsData(Map<String, dynamic> response) {
    if (!mounted) return;

    final List<Playlist> allPlaylists = (response['info'] as List)
        .map((item) => Playlist.fromJson(item as Map<String, dynamic>))
        .toList();

    final likedPlaylist = allPlaylists.firstWhere(
      (playlist) => playlist.name == '我喜欢',
      orElse: () => Playlist.empty(),
    );

    final otherPlaylists = allPlaylists
        .where((playlist) => playlist.name != '我喜欢')
        .toList()
      ..sort((a, b) => b.createTime.compareTo(a.createTime));

    setState(() {
      _likedPlaylist = likedPlaylist;
      _playlists = otherPlaylists;
      _playlistCount = otherPlaylists.length;
    });
  }

  // 修改登录回调
  Future<void> _handleLoginTap() async {
    final result = await Navigator.of(context).pushNamed('/login');
    if (result != null && context.read<AuthBloc>().state is AuthAuthenticated) {
      await _refreshFromServer(); // 只在登录成功时刷新服务器数据
    }
  }

  // 处理登出
  void _handleLogout() {
    if (context.read<AuthBloc>().state is! AuthAuthenticated) {
      _handleLoginTap();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('您确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isAuthenticated = state is AuthAuthenticated;
        final user = isAuthenticated ? (state).user : null;

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: _refreshFromServer,
            child: _buildMainContent(isAuthenticated, user),
          ),
        );
      },
    );
  }

  // 构建主要内容
  Widget _buildMainContent(bool isAuthenticated, User? user) {
    return Container(
      decoration: _buildGradientDecoration(),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(isAuthenticated),
          SliverToBoxAdapter(
            child: _isLoading
                ? const ProfileTabSkeleton() // 加载时显示骨架屏
                : Column(
                    children: [
                      _buildUserInfoCard(isAuthenticated, user),
                      _buildSettingsSection(context), // 将设置移到上方
                      _buildFeatureSection(isAuthenticated),
                      if (isAuthenticated) _buildRecentSection(),
                      _buildPlaylistSection(isAuthenticated),
                      const SizedBox(height: 100),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // 构建渐变背景
  BoxDecoration _buildGradientDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.blue[600]!,
          Colors.blue[50]!,
        ],
        stops: const [0.0, 0.7],
      ),
    );
  }

  // 构建AppBar
  Widget _buildAppBar(bool isAuthenticated) {
    return SliverAppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      expandedHeight: 100,
      pinned: true,
      floating: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.only(top: 40, left: 16, right: 16),
          child: Row(
            children: [
              const Text(
                '我的音乐',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 4.0,
                      color: Color.fromARGB(50, 0, 0, 0),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SearchPage()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (isAuthenticated)
                GestureDetector(
                  onTap: _handleLogout,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.logout,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建用户信息卡片
  Widget _buildUserInfoCard(bool isAuthenticated, User? user) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: user?.pic != null
                      ? Image.network(
                          user!.pic!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.person,
                                color: Colors.white, size: 25),
                          ),
                        )
                      : Container(
                          color: Theme.of(context).primaryColor,
                          child: const Icon(Icons.person,
                              color: Colors.white, size: 25),
                        ),
                ),
              ),
              if (user?.isVipValid ?? false)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.amber[700],
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'VIP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isAuthenticated ? user!.nickname : '立即登录',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    if (isAuthenticated && user!.isVipValid)
                      Text(
                        '会员 · 剩余${user.vipRemainingDays}天',
                        style: TextStyle(
                          color: Colors.amber[800],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (!isAuthenticated)
                      InkWell(
                        onTap: _handleLoginTap,
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '登录',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (isAuthenticated) ...[
                  Text(
                    'ID: ${user!.userId}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ] else ...[
                  Text(
                    '登录后享受更多功能',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建设置菜单部分 - 移到上方
  Widget _buildSettingsSection(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSettingItem(
            icon: themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
            label: themeProvider.isDarkMode ? '深色' : '浅色',
            onTap: () {
              context.read<ThemeProvider>().toggleTheme();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context.read<ThemeProvider>().isDarkMode
                        ? '已切换为深色模式'
                        : '已切换为浅色模式',
                  ),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          _buildSettingItem(
            icon: Icons.delete_outline,
            label: '清理',
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('确认清除'),
                  content: const Text('确定要清除所有缓存音乐吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('确定'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && mounted) {
                try {
                  final cacheManager = await AudioCacheManager.getInstance();
                  await cacheManager.clearAllCached();
                  await _loadLocalSongCount();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('缓存已清除')),
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('清除缓存失败: $e')),
                    );
                  }
                }
              }
            },
          ),
          _buildSettingItem(
            icon: Icons.more_horiz,
            label: '更多',
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                builder: (context) => _buildMoreSettingsSheet(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreSettingsSheet() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.purple[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline,
                color: Colors.purple[400],
                size: 20,
              ),
            ),
            title: const Text('关于'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: '酷狗音乐',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2024 酷狗音乐',
                children: [
                  const SizedBox(height: 24),
                  const Text('这是一个模拟酷狗音乐的Flutter应用。'),
                ],
              );
            },
          ),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.teal[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.settings_outlined,
                color: Colors.teal[400],
                size: 20,
              ),
            ),
            title: const Text('高级设置'),
            onTap: () {
              // 实现高级设置功能
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // 构建功能区域
  Widget _buildFeatureSection(bool isAuthenticated) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildFeatureItem(
            icon: Icons.favorite,
            label: '我喜欢',
            count: _likedPlaylist.count.toString(),
            color: Colors.red[400]!,
            onTap: () => _handleFeatureItemTap(FeatureType.favorite),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.access_time,
            label: '最近播放',
            count: isAuthenticated ? '$_recentSongsCount' : '0',
            color: Colors.blue[400]!,
            onTap: () => _handleFeatureItemTap(FeatureType.recent),
          ),
          _buildDivider(),
          _buildFeatureItem(
            icon: Icons.download_outlined,
            label: '本地音乐',
            count: _localSongCount.toString(),
            color: Colors.green[400]!,
            onTap: () => _handleFeatureItemTap(FeatureType.local),
          ),
        ],
      ),
    );
  }

  // 构建分隔线
  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 35,
      color: Colors.grey[200],
    );
  }

  // 构建功能项
  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required String count,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 处理功能项点击
  void _handleFeatureItemTap(FeatureType type) {
    switch (type) {
      case FeatureType.favorite:
        _handleFavoritesTap();
        break;
      case FeatureType.recent:
        _handleRecentTap();
        break;
      case FeatureType.local:
        _handleLocalTap();
        break;
    }
  }

  void _handleFavoritesTap() {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) {
      _handleLoginTap();
      return;
    }
    if (_likedPlaylist.globalCollectionId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MusicListScreen(
            type: MusicListType.favorite,
            title: '我喜欢',
            playlist: _likedPlaylist,
          ),
        ),
      );
    }
  }

  void _handleRecentTap() {
    final state = context.read<AuthBloc>().state;
    if (state is! AuthAuthenticated) {
      _handleLoginTap();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MusicListScreen(
          type: MusicListType.recent,
          title: '最近播放',
        ),
      ),
    );
  }

  void _handleLocalTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LocalSongsPage(),
      ),
    ).then((_) => _loadLocalSongCount());
  }

  Widget _buildRecentSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const RecentSongsSection(),
    );
  }

  Widget _buildPlaylistSection(bool isAuthenticated) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '我的歌单',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isAuthenticated ? '$_playlistCount' : '0',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: isAuthenticated
                      ? () {
                          // TODO: 添加歌单功能
                        }
                      : () => _handleLoginTap(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isAuthenticated && _playlists.isNotEmpty)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _playlists.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Colors.grey[200],
              ),
              itemBuilder: (context, index) {
                final playlist = _playlists[index];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MusicListScreen(
                          type: MusicListType.playlist,
                          title: playlist.name,
                          playlist: playlist,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.grey[100],
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: playlist.pic.isNotEmpty
                              ? Image.network(
                                  ImageUtils.getThumbnailUrl(playlist.pic),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.music_note,
                                      color: Colors.grey[400],
                                      size: 24,
                                    );
                                  },
                                )
                              : Icon(
                                  Icons.music_note,
                                  color: Colors.grey[400],
                                  size: 24,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                playlist.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${playlist.count}首',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.grey[400],
                        ),
                      ],
                    ),
                  ),
                );
              },
            )
          else if (isAuthenticated)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(
                    Icons.playlist_add,
                    size: 48,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '还没有创建歌单',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // TODO: 添加歌单
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('创建歌单'),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Icon(
                    Icons.lock,
                    size: 48,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '登录后查看歌单',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _handleLoginTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 2,
                    ),
                    child: const Text('去登录'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// 功能类型枚举
enum FeatureType {
  favorite,
  recent,
  local,
}

class _CategoryTab extends StatelessWidget {
  final bool isSelected;
  final String text;

  const _CategoryTab({
    required this.isSelected,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.blue : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 20,
          height: 2,
          color: isSelected ? Colors.blue : Colors.transparent,
        ),
      ],
    );
  }
}

// 播放器页面核心设计
class MusicPlayerPage extends StatefulWidget {
  final Song song;

  const MusicPlayerPage({super.key, required this.song});

  @override
  _MusicPlayerPageState createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 封面区域
          Expanded(
            flex: 5,
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                height: MediaQuery.of(context).size.width * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                  image: DecorationImage(
                    image: NetworkImage(widget.song.cover),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),

          // 歌曲信息
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Text(
                  widget.song.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.song.artists,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          // 进度条
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                      activeTrackColor: Colors.red[400],
                      inactiveTrackColor: Colors.grey[300],
                      thumbColor: Colors.red[400],
                    ),
                    child: Slider(
                      value: 0.3, // 播放进度
                      onChanged: (value) {},
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('0:00', style: TextStyle(color: Colors.grey[600])),
                        Text('3:24', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 控制按钮
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, size: 36),
                  onPressed: () {},
                ),
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red[400],
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 40,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPlaying = !_isPlaying;
                        if (_isPlaying) {
                          _animationController.forward();
                        } else {
                          _animationController.reverse();
                        }
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next, size: 36),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // 下一首歌曲预览
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: const DecorationImage(
                        image: NetworkImage('下一首歌曲封面URL'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '下一首歌曲名称',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '下一首歌曲歌手',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    '3:31',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  IconButton(
                    icon: Icon(Icons.favorite_border, color: Colors.grey[400]),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
