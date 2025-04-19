import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/play_song_info.dart';
import '../../core/providers/provider_manager.dart';
import '../../hooks/getTitle_ArtistName.dart';
import '../../services/player_service.dart';
import '../../services/storage/cache_manager.dart';
import '../../utils/image_utils.dart';
import '../widgets/mini_player.dart';

/// 音乐列表页面，用于显示歌单中的歌曲
class MusicListScreen extends ConsumerStatefulWidget {
  /// 歌单标题
  final String title;

  /// 歌单ID，用于从网络获取歌曲列表
  final String? playlistId;

  /// 直接传入的歌曲列表，当不需要从网络获取时使用
  final List<PlaySongInfo>? playlist;

  /// 构造函数，playlistId 和 playlist 必须提供一个
  const MusicListScreen({
    super.key,
    required this.title,
    this.playlistId,
    this.playlist,
  }) : assert(
            playlistId != null || playlist != null, '必须提供playlistId或playlist');

  @override
  ConsumerState<MusicListScreen> createState() => _MusicListScreenState();
}

class _MusicListScreenState extends ConsumerState<MusicListScreen> {
  final List<PlaySongInfo> _songs = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  dynamic _error;
  final int _pageSize = 30;
  
  // 搜索相关变量
  List<PlaySongInfo> _filteredSongs = [];
  bool _isSearching = false;
  String _searchQuery = "";
  bool _isShowingSearchBar = false;
  bool _isLoadingAllSongs = false; // 是否正在加载全部歌曲
  final TextEditingController _searchController = TextEditingController();
  
  // 缓存相关
  late CacheManager _cacheManager; // 使用缓存管理器

  @override
  void initState() {
    super.initState();
    
    // 初始化缓存管理器
    _cacheManager = CacheManager(ref.read(ProviderManager.sharedPreferencesProvider));

    if (widget.playlistId != null) {
      // 先检查缓存
      _loadCachedSongs().then((hasCachedSongs) {
        if (!hasCachedSongs) {
          _loadInitialSongs();
        }
      });
      _scrollController.addListener(_onScroll);
    } else if (widget.playlist != null) {
      setState(() {
        _songs.addAll(widget.playlist!);
        _hasMore = false;
      });
    }
    
    // 初始化搜索结果为全部歌曲
    _filteredSongs = _songs;
  }
  
  /// 加载缓存的歌曲
  Future<bool> _loadCachedSongs() async {
    if (widget.playlistId == null) return false;
    
    final cachedSongs = _cacheManager.getCachedPlaySongInfoList(widget.playlistId!);
    if (cachedSongs != null && cachedSongs.isNotEmpty) {
      setState(() {
        _songs.addAll(cachedSongs);
        _filteredSongs = _songs;
        _hasMore = false; // 已经缓存了全部歌曲
      });
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        widget.playlistId != null) {
      _loadMoreSongs();
    }
  }

  /// 加载初始歌曲 (第一页)
  Future<void> _loadInitialSongs() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _songs.clear();
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final newSongs = await _fetchSongs(_currentPage);
      setState(() {
        _songs.addAll(newSongs);
        _filteredSongs = _songs;
        _hasMore = newSongs.length == _pageSize;
        _isLoading = false;
      });
      
      // 如果歌单比较小，直接尝试预加载更多歌曲
      if (_hasMore && newSongs.length < 100) {
        _preloadMoreSongs();
      }
    } catch (e) {
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }
  
  /// 后台预加载更多歌曲
  Future<void> _preloadMoreSongs() async {
    if (!_hasMore || _isLoadingMore || widget.playlistId == null) return;
    
    try {
      // 加载下一页
      final nextPage = _currentPage + 1;
      final newSongs = await _fetchSongs(nextPage);
      
      if (mounted) {
        setState(() {
          _songs.addAll(newSongs);
          _filteredSongs = _isSearching ? _performSearchFilter(_searchQuery) : _songs;
          _currentPage = nextPage;
          _hasMore = newSongs.length == _pageSize;
        });
      }
    } catch (e) {
      // 预加载失败不显示错误，静默处理
      print('预加载失败: $e');
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
      _error = null;
    });
    _currentPage++;
    try {
      final newSongs = await _fetchSongs(_currentPage);
      setState(() {
        _songs.addAll(newSongs);
        _hasMore = newSongs.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _currentPage--;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载更多失败: $e')),
        );
      }
    }
  }

  /// 从API获取歌曲数据 (支持分页)
  Future<List<PlaySongInfo>> _fetchSongs(int page) async {
    if (widget.playlistId == null || widget.playlistId!.isEmpty) {
      throw Exception('歌单ID无效');
    }

    final tracks = await ref
        .read(ProviderManager.apiServiceProvider)
        .getPlaylistTracks(widget.playlistId!, page: page, pageSize: _pageSize, forceRefresh: page == 1);

    if (tracks.isEmpty) {
      return [];
    }

    final songList = tracks.map((map) {
      try {
        return PlaySongInfo.fromJson(map);
      } catch (e) {
        return PlaySongInfo(
          hash: map['hash'] ?? '',
          title: map['title'] ?? map['songName'] ?? '未知歌曲',
          artist: map['artist'] ?? map['singerName'] ?? '未知艺术家',
        );
      }
    }).toList();
    
    // 如果加载了所有歌曲，则更新缓存
    if (!_hasMore && widget.playlistId != null) {
      // 将完整歌单缓存
      final allSongs = List<PlaySongInfo>.from(_songs);
      if (page > 1) {
        allSongs.addAll(songList);
      }
      _cacheManager.cachePlaySongInfoList(widget.playlistId!, allSongs);
    }
    
    return songList;
  }

  /// 下拉刷新处理
  Future<void> _handleRefresh() async {
    if (widget.playlistId != null) {
      await _loadInitialSongs();
    }
  }
  
  // 显示搜索框
  void _showSearchBar() async {
    // 如果是要显示搜索框，先检查是否需要加载全部歌曲
    if (!_isShowingSearchBar && widget.playlistId != null && _hasMore) {
      // 显示加载提示
      setState(() {
        _isLoadingAllSongs = true;
        _isShowingSearchBar = true;
      });
      
      // 加载所有歌曲
      await _loadAllSongs();
      
      setState(() {
        _isLoadingAllSongs = false;
      });
    } else {
      setState(() {
        _isShowingSearchBar = !_isShowingSearchBar;
        if (!_isShowingSearchBar) {
          _clearSearch();
        }
      });
    }
  }
  
  // 加载歌单的所有歌曲
  Future<void> _loadAllSongs() async {
    if (!_hasMore || widget.playlistId == null) return;
    
    try {
      int page = _currentPage + 1;
      bool hasMoreToLoad = true;
      List<PlaySongInfo> allNewSongs = [];
      
      // 持续加载直到没有更多歌曲
      while (hasMoreToLoad) {
        final newSongs = await _fetchSongs(page);
        if (newSongs.isEmpty || newSongs.length < _pageSize) {
          hasMoreToLoad = false;
        }
        
        allNewSongs.addAll(newSongs);
        setState(() {
          _songs.addAll(newSongs);
          _filteredSongs = _isSearching ? _performSearchFilter(_searchQuery) : _songs;
          _currentPage = page;
        });
        
        page++;
      }
      
      setState(() {
        _hasMore = false;
      });
      
      // 缓存所有歌曲
      if (widget.playlistId != null) {
        _cacheManager.cachePlaySongInfoList(widget.playlistId!, _songs);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载全部歌曲失败: $e')),
        );
      }
    }
  }
  
  // 执行搜索
  void _performSearch(String query) {
    if (query.isEmpty) {
      _clearSearch();
      return;
    }
    
    setState(() {
      _searchQuery = query;
      _isSearching = true;
      
      // 在歌曲列表中搜索匹配的歌曲
      _filteredSongs = _performSearchFilter(query);
    });
  }
  
  // 搜索过滤函数，返回过滤后的列表
  List<PlaySongInfo> _performSearchFilter(String query) {
    final searchLower = query.toLowerCase();
    
    return _songs.where((song) {
      final title = song.title.toLowerCase();
      final artist = song.artist.toLowerCase();
      
      return title.contains(searchLower) || artist.contains(searchLower);
    }).toList();
  }
  
  // 清除搜索
  void _clearSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = "";
      _filteredSongs = _songs;
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerService = ref.watch(ProviderManager.playerServiceProvider);
    final currentPlayingSongHash = playerService.currentSongInfo?.hash;

    return Scaffold(
      backgroundColor: Colors.white, // 将Scaffold背景设为白色
      appBar: AppBar(
        title: Text(widget.title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white, // AppBar背景设为白色
        centerTitle: true, // 标题居中
        actions: [
          IconButton(
            icon: Icon(_isShowingSearchBar ? Icons.search_off : Icons.search),
            tooltip: _isShowingSearchBar ? '关闭搜索' : '搜索歌单内歌曲',
            onPressed: () {
              _showSearchBar();
            },
          ),
          const SizedBox(width: 8), // 右边留点空隙
        ],
      ),
      body: Column(
        children: [
          // 搜索框，只在显示时才添加
          if (_isShowingSearchBar)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoadingAllSongs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('正在加载全部歌曲以优化搜索...', 
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: _isLoadingAllSongs ? '正在加载全部歌曲...' : '输入歌曲名或歌手名',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _clearSearch();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) {
                      if (value.isEmpty) {
                        _clearSearch();
                      } else {
                        _performSearch(value);
                      }
                    },
                    enabled: !_isLoadingAllSongs,
                  ),
                ],
              ),
            ),
          // 移除外部包裹的Container和ClipRRect
          Expanded(
            child: RefreshIndicator(
              onRefresh: _handleRefresh,
              child: _buildBody(playerService, currentPlayingSongHash),
            ),
          ),
          // 底部迷你播放器
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildBody(
      PlayerService playerService, String? currentPlayingSongHash) {
    if (_isLoading && _songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              '加载失败: $_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialSongs,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_songs.isEmpty) {
      return const Center(child: Text('暂无歌曲'));
    }
    
    // 如果正在搜索但没有结果
    if (_isSearching && _filteredSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              '没有找到匹配 "$_searchQuery" 的歌曲',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _clearSearch,
              child: const Text('清除搜索'),
            ),
          ],
        ),
      );
    }

    // 使用搜索结果或全部歌曲
    final displaySongs = _isSearching ? _filteredSongs : _songs;
    
    return ListView.builder(
      controller: _scrollController,
      itemCount: displaySongs.length +
          (_isLoadingMore && !_isSearching ? 1 : 0) +
          (!_hasMore && widget.playlistId != null && !_isLoadingMore && !_isSearching ? 1 : 0),
      itemBuilder: (context, index) {
        // 处理加载更多和没有更多的情况
        if (!_isSearching && index == displaySongs.length) {
          if (_isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.0)),
            );
          } else if (!_hasMore && widget.playlistId != null) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                  child: Text('--- 没有更多了 ---',
                      style: TextStyle(color: Colors.grey))),
            );
          } else {
            return const SizedBox.shrink();
          }
        }

        final song = displaySongs[index];
        final isPlaying = currentPlayingSongHash != null &&
            song.hash == currentPlayingSongHash;

        return Container(
            decoration: BoxDecoration(
              color: isPlaying ? Colors.grey[100] : null,
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[300],
                  child: song.cover != null && song.cover!.isNotEmpty
                      ? ImageUtils.createCachedImage(
                          ImageUtils.getThumbnailUrl(song.cover),
                          fit: BoxFit.cover,
                          width: 50,
                          height: 50,
                        )
                      : Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                ),
              ),
              title: Text(
                getSongTitle(song.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isPlaying ? Colors.pink : null,
                  fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isPlaying ? Colors.pink : Colors.grey[600],
                  fontSize: 12.0,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isPlaying)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up, color: Colors.pink, size: 16.0),
                          const SizedBox(width: 4.0),
                          Text(
                            '正在播放',
                            style: TextStyle(
                              color: Colors.pink,
                              fontSize: 10.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 8.0),
                  Icon(Icons.more_vert, color: Colors.grey[400], size: 20.0),
                ],
              ),
              onTap: () async {
                try {
                  // 如果在搜索模式下，需要找到原始列表中的索引
                  int originalIndex = index;
                  if (_isSearching) {
                    originalIndex = _songs.indexWhere((s) => s.hash == song.hash);
                  }
                  
                  playerService.preparePlaylist(_songs, originalIndex);
                  await playerService.play(song);
                  // 不再导航到播放页面，直接在当前页面放
                  // if (mounted) {
                  //   Navigator.of(context).push(
                  //     MaterialPageRoute(
                  //       builder: (context) => const PlayerPage(),
                  //     ),
                  //   );
                  // }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('播放失败: $e')),
                    );
                  }
                }
              },
            ));
      },
    );
  }
}
