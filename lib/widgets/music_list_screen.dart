import 'package:flutter/material.dart';
import 'package:my_music_app/utils/image_utils.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/api_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/player_service.dart';
import '../pages/player_page.dart';

enum MusicListType {
  favorite,
  recent,
  local,
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

class _MusicListScreenState extends State<MusicListScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
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
      if (widget.playlist != null) {
        final apiService = context.read<ApiService>();
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
      } else {
        switch (widget.type) {
          case MusicListType.favorite:
            // TODO: 加载收藏的音乐
            break;
          case MusicListType.recent:
            // TODO: 加载最近播放
            break;
          case MusicListType.local:
            // TODO: 加载本地音乐
            break;
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
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

      // 准备播放列表和当前歌曲
      playerService.preparePlaylist(_songs, songIndex);
      await playerService.setCurrentSong(song);

      // 开始播放
      await playerService.startPlayback();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
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
            icon: const Icon(Icons.sort),
            onPressed: _showSortMenu,
          ),
        ],
      ),
      body: _isLoading && _currentPage == 1
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
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            song.artists,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showSongMenu(song),
                    ),
                    onTap: () => _playSong(song),
                  );
                },
              ),
            ),
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
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
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
          onTap: () {
            close(context, query);
          },
        );
      },
    );
  }
}
