import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:my_music_app/utils/image_utils.dart';
import '../bloc/auth/auth_bloc.dart';
import '../services/api_service.dart';
import '../services/audio_cache_manager.dart';
import '../models/playlist.dart';
import 'music_list_screen.dart';
import 'recent_songs_section.dart';
import '../pages/recent_songs_page.dart';
import '../pages/search_page.dart';
import '../pages/local_songs_page.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with AutomaticKeepAliveClientMixin {
  List<Playlist> _playlists = [];
  int _playlistCount = 0;
  Playlist _likedPlaylist = Playlist.empty();
  bool _isFirstLoad = true;
  bool _isPurchasedExpanded = false;
  int _localSongCount = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadLocalSongCount();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AuthBloc>().state;
    // 只在第一次加载时从缓存获取数据
    if (_isFirstLoad && state is AuthAuthenticated) {
      _isFirstLoad = false;
      _loadFromCache();
    }
  }

  Future<void> _loadLocalSongCount() async {
    try {
      final cacheManager = await AudioCacheManager.getInstance();
      final count = await cacheManager.getCachedCount();
      if (mounted) {
        setState(() {
          _localSongCount = count;
        });
      }
    } catch (e) {
      print('加载本地歌曲数量失败: $e');
    }
  }

  // 从缓存加载数据
  Future<void> _loadFromCache() async {
    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.getUserPlaylists();
      _updatePlaylistsData(response);
    } catch (e) {
      print('从缓存加载数据失败: $e');
    }
  }

  // 从服务器刷新数据
  Future<void> _refreshFromServer() async {
    try {
      await _loadLocalSongCount(); // 刷新本地歌曲数量
      final apiService = context.read<ApiService>();
      final response = await apiService.getUserPlaylists(forceRefresh: true);
      _updatePlaylistsData(response);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新歌单失败: $e')),
        );
      }
    }
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

  void _handleLoginTap() {
    Navigator.of(context).pushNamed('/login').then((_) {
      // 从登录页面返回后，检查是否需要刷新用户信息
      final state = context.read<AuthBloc>().state;
      if (state is AuthAuthenticated) {
        _refreshFromServer();
      }
    });
  }

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
    super.build(context); // 必须调用 super.build

    final state = context.watch<AuthBloc>().state;
    final isAuthenticated = state is AuthAuthenticated;
    final user = isAuthenticated ? (state).user : null;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshFromServer,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue[300]!,
                Colors.blue[100]!,
              ],
            ),
          ),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                elevation: 0,
                backgroundColor: Colors.transparent,
                title: Row(
                  children: [
                    const Text(
                      '我的',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          print('顶部搜索框被点击');
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SearchPage(),
                            ),
                          );
                        },
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '搜索音乐、歌手、歌词',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (isAuthenticated)
                    IconButton(
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.white,
                      ),
                      onPressed: _handleLogout,
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    if (state is AuthLoading)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ),
                    // 用户信息卡片
                    Container(
                      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.8),
                            Theme.of(context).primaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(1.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.6),
                                    width: 1,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor:
                                      Colors.white.withOpacity(0.2),
                                  backgroundImage: user?.pic != null
                                      ? NetworkImage(user!.pic!)
                                      : null,
                                  child: user?.pic == null
                                      ? const Icon(Icons.person,
                                          color: Colors.white, size: 24)
                                      : null,
                                ),
                              ),
                              if (user?.isVip ?? false)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 3, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.amber[700],
                                      borderRadius: BorderRadius.circular(4),
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAuthenticated ? user!.nickname : '立即登录',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                if (isAuthenticated) ...[
                                  const SizedBox(height: 1),
                                  Text(
                                    'ID: ${user!.userId}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isAuthenticated && user!.isVip)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.workspace_premium,
                                    color: Colors.amber,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${DateTime.parse(user.vipEndTime!).difference(DateTime.now()).inDays}天',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // 功能区域
                    Container(
                      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFEEEEEE),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFeatureItem(
                            icon: Icons.favorite,
                            label: '我喜欢',
                            count: _likedPlaylist.count.toString(),
                            color: Colors.red[400]!,
                            onTap: () {
                              final state = context.read<AuthBloc>().state;
                              if (state is! AuthAuthenticated) {
                                _handleLoginTap();
                                return;
                              }
                              // 如果有"我喜欢"歌单，导航到歌单页面
                              if (_likedPlaylist
                                  .globalCollectionId.isNotEmpty) {
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
                            },
                          ),
                          Container(
                            width: 0.5,
                            height: 20,
                            color: const Color(0xFFEEEEEE),
                          ),
                          _buildFeatureItem(
                            icon: Icons.access_time,
                            label: '最近',
                            count: isAuthenticated ? '30' : '0',
                            color: Colors.blue[400]!,
                            onTap: () {
                              final state = context.read<AuthBloc>().state;
                              if (state is! AuthAuthenticated) {
                                _handleLoginTap();
                                return;
                              }
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RecentSongsPage(),
                                ),
                              );
                            },
                          ),
                          Container(
                            width: 0.5,
                            height: 20,
                            color: const Color(0xFFEEEEEE),
                          ),
                          _buildFeatureItem(
                            icon: Icons.download_outlined,
                            label: '本地',
                            count: _localSongCount.toString(),
                            color: Colors.green[400]!,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const LocalSongsPage(),
                                ),
                              ).then((_) => _loadLocalSongCount());
                            },
                          ),
                        ],
                      ),
                    ),

                    // 最近播放区域
                    if (isAuthenticated)
                      Container(
                        margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFEEEEEE),
                            width: 0.5,
                          ),
                        ),
                        child: const RecentSongsSection(),
                      ),

                    // 我的音乐组
                    Container(
                      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFEEEEEE),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          // 我的歌单标题
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 2,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '我的歌单',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isAuthenticated
                                      ? _playlistCount.toString()
                                      : '0',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11,
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: isAuthenticated
                                      ? () {
                                          // TODO: 添加歌单功能
                                        }
                                      : () => _handleLoginTap(),
                                  child: Icon(
                                    Icons.add,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 歌单列表
                          if (isAuthenticated)
                            for (var playlist in _playlists)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    height: 0.5,
                                    color: const Color(0xFFEEEEEE),
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MusicListScreen(
                                            type: MusicListType.favorite,
                                            title: playlist.name,
                                            playlist: playlist,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        child: SizedBox(
                                          height: 50,
                                          child: Row(
                                            children: [
                                              // 封面图片
                                              Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                  color: Colors.grey[100],
                                                ),
                                                clipBehavior: Clip.antiAlias,
                                                child: playlist.pic.isNotEmpty
                                                    ? Image.network(
                                                        ImageUtils
                                                            .getThumbnailUrl(
                                                                playlist.pic),
                                                        fit: BoxFit.cover,
                                                        errorBuilder: (context,
                                                            error, stackTrace) {
                                                          return Icon(
                                                            Icons.music_note,
                                                            color: Colors
                                                                .grey[400],
                                                            size: 20,
                                                          );
                                                        },
                                                      )
                                                    : Icon(
                                                        Icons.music_note,
                                                        color: Colors.grey[400],
                                                        size: 20,
                                                      ),
                                              ),
                                              const SizedBox(width: 8),
                                              // 标题和副标题
                                              Expanded(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceAround,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      playlist.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${playlist.count}首',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ),
                                ],
                              ),
                          // 已购音乐部分
                          Container(
                            height: 0.5,
                            color: const Color(0xFFEEEEEE),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          // 已购音乐标题
                          InkWell(
                            onTap: () {
                              setState(() {
                                _isPurchasedExpanded = !_isPurchasedExpanded;
                              });
                            },
                            child: SizedBox(
                              height: 40,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  children: [
                                    const Text(
                                      '已购音乐',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      _isPurchasedExpanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // 已购音乐列表项
                          if (_isPurchasedExpanded) ...[
                            SizedBox(
                              height: 46,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.purple[50],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(Icons.album,
                                          color: Colors.purple[400], size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '数字专辑',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '0张',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              height: 0.5,
                              color: const Color(0xFFEEEEEE),
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            SizedBox(
                              height: 46,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(Icons.music_note,
                                          color: Colors.green[400], size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '付费单曲',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '0首',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    required String count,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                count,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
