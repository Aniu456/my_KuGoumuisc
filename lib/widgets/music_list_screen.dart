import 'package:flutter/material.dart';
import 'package:my_music_app/utils/image_utils.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../models/play_song_info.dart';
import '../services/api_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/player_service.dart';
import '../pages/player_page.dart';

// 列表类型枚举
enum MusicListType {
  favorite,
  recent,
  local,
  playlist,
}

// 排序方式枚举
enum SortOrder {
  newest,
  oldest,
}

// 常量定义
class _Constants {
  static const double fabSize = 40.0;
  static const double playerFabSize = 70.0;
  static const double itemHeight = 72.0;
  static const int pageSize = 30;
  static const Duration animationDuration = Duration(milliseconds: 500);
  static const Duration rotationDuration = Duration(seconds: 10);

  static const EdgeInsets contentPadding = EdgeInsets.all(16.0);
  static const EdgeInsets itemPadding = EdgeInsets.symmetric(horizontal: 8.0);

  static final gradientColors = [
    Colors.blue[300]!.withOpacity(0.9),
    Colors.blue[400]!.withOpacity(0.9),
  ];

  static final playerGradientColors = [
    Colors.blue[400]!,
    Colors.blue[600]!,
  ];
}

class MusicListScreen extends StatefulWidget {
  final MusicListType type;
  final String title;
  final Playlist? playlist;

  const MusicListScreen({
    super.key,
    required this.type,
    required this.title,
    this.playlist,
  });

  @override
  State<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends State<MusicListScreen>
    with SingleTickerProviderStateMixin {
  // 控制器
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  late final AnimationController _rotationController;

  // 状态变量
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<Song> _songs = [];
  List<Song> _filteredSongs = [];
  int _currentPage = 1;
  SortOrder _sortOrder = SortOrder.newest;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadMusicList();
  }

  void _initializeControllers() {
    _rotationController = AnimationController(
      duration: _Constants.rotationDuration,
      vsync: this,
    );

    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 500) {
      _loadMoreSongs();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  // 加载音乐列表
  Future<void> _loadMusicList() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final apiService = context.read<ApiService>();
      final songs = await _fetchSongs(apiService);

      if (mounted) {
        setState(() {
          _songs = songs;
          _hasMore = songs.length >= _Constants.pageSize;
          _filterAndSortSongs();
        });
      }
    } catch (e) {
      _showError('加载失败: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 获取歌曲列表
  Future<List<Song>> _fetchSongs(ApiService apiService) async {
    switch (widget.type) {
      case MusicListType.favorite:
      case MusicListType.playlist:
        if (widget.playlist != null) {
          final songsData = await apiService.getPlaylistTracks(
            widget.playlist!.globalCollectionId,
            page: _currentPage,
            pageSize: _Constants.pageSize,
          );
          return songsData.map((data) => Song.fromJson(data)).toList();
        }
        return [];

      case MusicListType.recent:
        final response = await apiService.getRecentSongs();
        return response.songs
            .map((recentSong) => Song(
                  hash: recentSong.hash,
                  name: '${recentSong.singername} - ${recentSong.name}',
                  cover: recentSong.cover,
                  albumId: recentSong.albumId,
                  audioId: recentSong.audioId,
                  size: 0,
                  singerName: recentSong.singername,
                  albumImage: recentSong.cover,
                ))
            .toList();

      case MusicListType.local:
        // TODO: 实现本地音乐加载
        return [];
    }
  }

  // 加载更多歌曲
  Future<void> _loadMoreSongs() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;
    setState(() => _isLoadingMore = true);

    try {
      final apiService = context.read<ApiService>();
      final nextPage = _currentPage + 1;
      final songsData = await apiService.getPlaylistTracks(
        widget.playlist!.globalCollectionId,
        page: nextPage,
        pageSize: _Constants.pageSize,
      );

      if (songsData.isNotEmpty) {
        final newSongs = songsData.map((data) => Song.fromJson(data)).toList();
        setState(() {
          _songs.addAll(newSongs);
          _currentPage = nextPage;
          _hasMore = songsData.length >= _Constants.pageSize;
          _filterAndSortSongs();
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      _showError('加载更多失败: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  // 过滤和排序歌曲
  void _filterAndSortSongs() {
    var filtered = List<Song>.from(_songs);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((song) {
        return song.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    if (_sortOrder == SortOrder.oldest) {
      filtered = filtered.reversed.toList();
    }

    setState(() => _filteredSongs = filtered);
  }

  // 显示排序菜单
  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _SortMenuSheet(
        currentOrder: _sortOrder,
        onOrderChanged: (order) {
          setState(() {
            _sortOrder = order;
            _filterAndSortSongs();
          });
        },
      ),
    );
  }

  // 播放歌曲
  Future<void> _playSong(Song song) async {
    try {
      final playerService = context.read<PlayerService>();
      final songIndex = _songs.indexOf(song);

      // 1. 准备播放列表和歌曲
      final playlist = _songs.map((s) => PlaySongInfo.fromSong(s)).toList();
      playerService.preparePlaylist(playlist, songIndex);
      // 2. 开始播放
      await playerService.play(playlist[songIndex]);
    } catch (e) {
      _showError('播放失败: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildMusicList(),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: _buildFloatingButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // 构建AppBar
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: _AppBarTitle(
        title: widget.title,
        songCount: _filteredSongs.length,
      ),
      leading: _BackButton(onPressed: () => Navigator.of(context).pop()),
      actions: _buildAppBarActions(),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      IconButton(
        icon: const Icon(Icons.search, size: 22),
        color: Colors.black87,
        onPressed: () => _showSearch(),
      ),
      IconButton(
        icon: const Icon(Icons.sort, size: 22),
        color: Colors.black87,
        onPressed: _showSortMenu,
      ),
      const SizedBox(width: 4),
    ];
  }

  // 显示搜索
  void _showSearch() {
    showSearch(
      context: context,
      delegate: _SongSearchDelegate(_songs),
    ).then((searchQuery) {
      if (searchQuery != null) {
        setState(() {
          _searchQuery = searchQuery;
          _filterAndSortSongs();
        });
      }
    });
  }

  // 构建音乐列表
  Widget _buildMusicList() {
    if (_isLoading && _currentPage == 1) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadMusicList,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _filteredSongs.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _filteredSongs.length) {
            return _LoadMoreButton(
              isLoading: _isLoadingMore,
              onPressed: _loadMoreSongs,
            );
          }
          return _SongListItem(
            song: _filteredSongs[index],
            onTap: _playSong,
          );
        },
      ),
    );
  }

  // 构建浮动按钮
  Widget _buildFloatingButtons() {
    final playerService = context.watch<PlayerService>();
    final currentSong = playerService.currentSongInfo;
    final isPlaying = playerService.isPlaying;

    _updateRotationAnimation(isPlaying);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_filteredSongs.isNotEmpty) ...[
          _ScrollTopButton(onPressed: _scrollToTop),
          const SizedBox(height: 8),
        ],
        if (currentSong != null && _filteredSongs.isNotEmpty) ...[
          _CurrentSongButton(
            onPressed: () => _scrollToCurrentSong(currentSong),
          ),
          const SizedBox(height: 12),
        ],
        if (currentSong != null)
          _PlayerFloatingButton(
            currentSong: currentSong,
            rotationController: _rotationController,
          ),
      ],
    );
  }

  void _updateRotationAnimation(bool isPlaying) {
    if (isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: _Constants.animationDuration,
      curve: Curves.easeInOut,
    );
  }

  void _scrollToCurrentSong(PlaySongInfo currentSong) {
    final currentIndex =
        _filteredSongs.indexWhere((song) => song.hash == currentSong.hash);
    if (currentIndex != -1) {
      _scrollController.animateTo(
        currentIndex * _Constants.itemHeight,
        duration: _Constants.animationDuration,
        curve: Curves.easeInOut,
      );
    }
  }
}

// 提取的组件
class _AppBarTitle extends StatelessWidget {
  final String title;
  final int songCount;

  const _AppBarTitle({required this.title, required this.songCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (songCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            '$songCount首歌曲',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
      color: Colors.black87,
      onPressed: onPressed,
    );
  }
}

class _LoadMoreButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _LoadMoreButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _Constants.contentPadding,
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : TextButton(
                onPressed: onPressed,
                child: const Text('加载更多'),
              ),
      ),
    );
  }
}

class _SongListItem extends StatelessWidget {
  final Song song;
  final ValueChanged<Song> onTap;

  const _SongListItem({
    required this.song,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final playerService = context.watch<PlayerService>();
    final currentSong = playerService.currentSongInfo;
    final isCurrentSong = currentSong != null && song.hash == currentSong.hash;

    return ListTile(
      leading: _SongCover(coverUrl: song.cover),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrentSong ? Theme.of(context).primaryColor : null,
          fontWeight: isCurrentSong ? FontWeight.bold : null,
        ),
      ),
      subtitle: _SongArtists(
        artists: song.artists,
        isCurrentSong: isCurrentSong,
      ),
      tileColor: isCurrentSong
          ? Theme.of(context).primaryColor.withOpacity(0.05)
          : null,
      onTap: () => onTap(song),
    );
  }
}

class _SongCover extends StatelessWidget {
  final String coverUrl;

  const _SongCover({required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: Colors.grey[100],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: coverUrl.isNotEmpty
            ? Image.network(
                ImageUtils.getThumbnailUrl(coverUrl),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.music_note,
                    color: Colors.grey[400],
                  );
                },
              )
            : Icon(
                Icons.music_note,
                color: Colors.grey[400],
              ),
      ),
    );
  }
}

class _SongArtists extends StatelessWidget {
  final String artists;
  final bool isCurrentSong;

  const _SongArtists({
    required this.artists,
    required this.isCurrentSong,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            artists,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrentSong
                  ? Theme.of(context).primaryColor.withOpacity(0.7)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _SortMenuSheet extends StatelessWidget {
  final SortOrder currentOrder;
  final ValueChanged<SortOrder> onOrderChanged;

  const _SortMenuSheet({
    required this.currentOrder,
    required this.onOrderChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SortMenuItem(
            title: '最新添加',
            isSelected: currentOrder == SortOrder.newest,
            onTap: () {
              onOrderChanged(SortOrder.newest);
              Navigator.pop(context);
            },
          ),
          _SortMenuItem(
            title: '最早添加',
            isSelected: currentOrder == SortOrder.oldest,
            onTap: () {
              onOrderChanged(SortOrder.oldest);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

class _SortMenuItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortMenuItem({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: isSelected
          ? const Icon(Icons.check, color: Colors.blue)
          : const SizedBox(width: 24),
      title: Text(title),
      onTap: onTap,
    );
  }
}

class _SongMenuSheet extends StatelessWidget {
  final Song song;
  final VoidCallback onPlayTap;

  const _SongMenuSheet({
    required this.song,
    required this.onPlayTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('播放'),
            onTap: onPlayTap,
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('添加到播放列表'),
            onTap: () {
              Navigator.pop(context);
              // TODO: 实现添加到播放列表功能
            },
          ),
          ListTile(
            leading: const Icon(Icons.favorite_border),
            title: const Text('收藏'),
            onTap: () {
              Navigator.pop(context);
              // TODO: 实现收藏功能
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('分享'),
            onTap: () {
              Navigator.pop(context);
              // TODO: 实现分享功能
            },
          ),
        ],
      ),
    );
  }
}

class _ScrollTopButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ScrollTopButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _Constants.fabSize,
      height: _Constants.fabSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _Constants.gradientColors,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: const Icon(
            Icons.vertical_align_top,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _CurrentSongButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CurrentSongButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _Constants.fabSize,
      height: _Constants.fabSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _Constants.gradientColors,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: const Icon(
            Icons.my_location,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _PlayerFloatingButton extends StatelessWidget {
  final PlaySongInfo currentSong;
  final AnimationController rotationController;

  const _PlayerFloatingButton({
    required this.currentSong,
    required this.rotationController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _Constants.playerFabSize,
      height: _Constants.playerFabSize,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _Constants.playerGradientColors,
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PlayerPage()),
          ),
          customBorder: const CircleBorder(),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 4,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  RotationTransition(
                    turns: rotationController,
                    child: Image.network(
                      ImageUtils.getThumbnailUrl(currentSong.cover ?? ''),
                      width: 65,
                      height: 65,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.music_note,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.transparent,
                          Colors.black.withOpacity(0.2),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 搜索代理
class _SongSearchDelegate extends SearchDelegate<String?> {
  final List<Song> songs;

  _SongSearchDelegate(this.songs);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('输入歌曲名称或歌手名称搜索'));
    }

    final results = songs.where((song) {
      return song.name.toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (results.isEmpty) {
      return const Center(child: Text('未找到相关歌曲'));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) => _SearchResultItem(
        song: results[index],
        onTap: () => _handleSongTap(context, results[index]),
      ),
    );
  }

  Future<void> _handleSongTap(BuildContext context, Song song) async {
    try {
      final playerService = context.read<PlayerService>();
      final songInfo = PlaySongInfo(
        hash: song.hash,
        title: song.title,
        artist: song.artists,
        cover: song.cover,
      );

      // 1. 先关闭搜索页面
      close(context, null);

      // 2. 准备播放
      await playerService.play(songInfo);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }
}

class _SearchResultItem extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;

  const _SearchResultItem({
    required this.song,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(song.title),
      subtitle: Text(song.artists),
      onTap: onTap,
    );
  }
}
