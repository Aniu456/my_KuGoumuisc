import 'package:flutter/material.dart';
import 'package:my_music_app/utils/image_utils.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../models/play_song_info.dart';
import '../services/api_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/player_service.dart';
import '../pages/player_page.dart';

enum MusicListType {
  favorite,
  recent,
  local,
  playlist,
}

enum SortOrder {
  newest,
  oldest,
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
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  late AnimationController _rotationController;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  List<Song> _songs = [];
  List<Song> _filteredSongs = [];
  int _currentPage = 1;
  final int _pageSize = 30;
  SortOrder _sortOrder = SortOrder.newest;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadMusicList();
    _setupScrollController();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 500) {
        _loadMoreSongs();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadMusicList() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final apiService = context.read<ApiService>();

      switch (widget.type) {
        case MusicListType.favorite:
        case MusicListType.playlist:
          if (widget.playlist != null) {
            final songsData = await apiService.getPlaylistTracks(
              widget.playlist!.globalCollectionId,
              page: _currentPage,
              pageSize: _pageSize,
            );

            setState(() {
              _songs =
                  songsData.map((songData) => Song.fromJson(songData)).toList();
              _hasMore = songsData.length >= _pageSize;
              _filterAndSortSongs();
            });
          }
          break;

        case MusicListType.recent:
          final response = await apiService.getRecentSongs();
          setState(() {
            _songs = response.songs
                .map((recentSong) => Song(
                      hash: recentSong.hash,
                      name: '${recentSong.singername} - ${recentSong.songname}',
                      cover: recentSong.cover,
                      albumId: '',
                      audioId: '',
                      size: 0,
                      singerName: recentSong.singername,
                      albumImage: recentSong.cover,
                    ))
                .toList();
            _hasMore = false; // 最近播放没有分页
            _filterAndSortSongs();
          });
          break;

        case MusicListType.local:
          // TODO: 加载本地音乐
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_isLoadingMore || !_hasMore || _isLoading) return;

    setState(() => _isLoadingMore = true);

    try {
      final apiService = context.read<ApiService>();
      final nextPage = _currentPage + 1;
      final songsData = await apiService.getPlaylistTracks(
        widget.playlist!.globalCollectionId,
        page: nextPage,
        pageSize: _pageSize,
      );

      if (songsData.isNotEmpty) {
        final newSongs =
            songsData.map((songData) => Song.fromJson(songData)).toList();

        setState(() {
          _songs.addAll(newSongs);
          _currentPage = nextPage;
          _hasMore = songsData.length >= _pageSize;
          _filterAndSortSongs();
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载更多失败: $e')),
      );
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _filterAndSortSongs() {
    var filtered = List<Song>.from(_songs);

    // 应用搜索过滤
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((song) {
        return song.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // 应用排序
    if (_sortOrder == SortOrder.oldest) {
      filtered = filtered.reversed.toList();
    }

    setState(() => _filteredSongs = filtered);
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: _sortOrder == SortOrder.newest
                    ? const Icon(Icons.check, color: Colors.blue)
                    : const SizedBox(width: 24),
                title: const Text('最新添加'),
                onTap: () {
                  setState(() {
                    _sortOrder = SortOrder.newest;
                    _filterAndSortSongs();
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: _sortOrder == SortOrder.oldest
                    ? const Icon(Icons.check, color: Colors.blue)
                    : const SizedBox(width: 24),
                title: const Text('最早添加'),
                onTap: () {
                  setState(() {
                    _sortOrder = SortOrder.oldest;
                    _filterAndSortSongs();
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSongMenu(Song song) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('播放'),
                onTap: () {
                  Navigator.pop(context);
                  _playSong(song);
                },
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
      },
    );
  }

  Future<void> _playSong(Song song) async {
    try {
      final playerService = context.read<PlayerService>();
      final songIndex = _songs.indexOf(song);

      // 先导航到播放页面
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PlayerPage(),
        ),
      );

      // 转换播放列表
      final playlist = _songs.map((s) => PlaySongInfo.fromSong(s)).toList();

      // 准备播放列表和当前歌曲
      playerService.preparePlaylist(playlist, songIndex);
      await playerService.play(playlist[songIndex]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerService = context.watch<PlayerService>();
    final currentSong = playerService.currentSongInfo;
    final isPlaying = playerService.isPlaying;

    // 控制旋转动画
    if (isPlaying && !_rotationController.isAnimating) {
      _rotationController.repeat();
    } else if (!isPlaying && _rotationController.isAnimating) {
      _rotationController.stop();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 4),
            if (_filteredSongs.isNotEmpty)
              Text(
                '${_filteredSongs.length}首歌曲',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          color: Colors.black87,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            color: Colors.black87,
            onPressed: () {
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
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort, size: 22),
            color: Colors.black87,
            onPressed: _showSortMenu,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey[200],
          ),
        ),
      ),
      body: Stack(
        children: [
          _isLoading && _currentPage == 1
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadMusicList,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _filteredSongs.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _filteredSongs.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: _isLoadingMore
                                ? const CircularProgressIndicator()
                                : TextButton(
                                    onPressed: _loadMoreSongs,
                                    child: const Text('加载更多'),
                                  ),
                          ),
                        );
                      }

                      final song = _filteredSongs[index];
                      final isCurrentSong =
                          currentSong != null && song.hash == currentSong.hash;
                      return ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.grey[100],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: song.cover.isNotEmpty
                                ? Image.network(
                                    ImageUtils.getThumbnailUrl(song.cover),
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
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrentSong
                                ? Theme.of(context).primaryColor
                                : null,
                            fontWeight: isCurrentSong ? FontWeight.bold : null,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text(
                                song.artists,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isCurrentSong
                                      ? Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.7)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                        tileColor: isCurrentSong
                            ? Theme.of(context).primaryColor.withOpacity(0.05)
                            : null,
                        onTap: () => _playSong(song),
                      );
                    },
                  ),
                ),
          // 底部空间,为悬浮按钮预留位置
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 跳转到第一首按钮
          if (_filteredSongs.isNotEmpty)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue[300]!.withOpacity(0.9),
                    Colors.blue[400]!.withOpacity(0.9),
                  ],
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
                  onTap: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  },
                  customBorder: const CircleBorder(),
                  child: const Icon(
                    Icons.vertical_align_top,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // 回到当前播放歌曲按钮
          if (currentSong != null && _filteredSongs.isNotEmpty)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue[300]!.withOpacity(0.9),
                    Colors.blue[400]!.withOpacity(0.9),
                  ],
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
                  onTap: () {
                    final currentIndex = _filteredSongs
                        .indexWhere((song) => song.hash == currentSong.hash);
                    if (currentIndex != -1) {
                      _scrollController.animateTo(
                        currentIndex * 72.0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  customBorder: const CircleBorder(),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          // 播放器悬浮按钮
          if (currentSong != null)
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue[400]!,
                    Colors.blue[600]!,
                  ],
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PlayerPage()),
                    );
                  },
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
                            turns: _rotationController,
                            child: Image.network(
                              ImageUtils.getThumbnailUrl(
                                  currentSong.cover ?? ''),
                              width: 65,
                              height: 65,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
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
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class _SongSearchDelegate extends SearchDelegate<String?> {
  final List<Song> songs;

  _SongSearchDelegate(this.songs);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    if (query.isEmpty) {
      return const Center(
        child: Text('输入歌曲名称或歌手名称搜索'),
      );
    }

    final results = songs.where((song) {
      return song.name.toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text('未找到相关歌曲'),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final song = results[index];
        return ListTile(
          title: Text(song.title),
          subtitle: Text(song.artists),
          onTap: () async {
            try {
              final playerService = context.read<PlayerService>();
              final songInfo = PlaySongInfo(
                hash: song.hash,
                title: song.title,
                artist: song.artists,
                cover: song.cover,
              );

              // 关闭搜索页面
              close(context, null);

              // 导航到播放页面
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PlayerPage(),
                ),
              );

              // 播放歌曲
              await playerService.play(songInfo);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('播放失败: $e')),
                );
              }
            }
          },
        );
      },
    );
  }
}
