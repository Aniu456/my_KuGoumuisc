import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/play_song_info.dart';
import '../core/providers/provider_manager.dart';
import '../utils/image_utils.dart';
import '../shared/widgets/mini_player.dart';
import '../services/storage/cache_manager.dart';

/// 已缓存页面，显示用户已缓存的歌曲
class RecentPlaysScreen extends ConsumerStatefulWidget {
  const RecentPlaysScreen({super.key});

  @override
  ConsumerState<RecentPlaysScreen> createState() => _RecentPlaysScreenState();
}

class _RecentPlaysScreenState extends ConsumerState<RecentPlaysScreen> {
  final List<PlaySongInfo> _songs = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  dynamic _error;

  // 搜索相关变量
  List<PlaySongInfo> _filteredSongs = [];
  bool _isSearching = false;
  bool _isShowingSearchBar = false;
  final TextEditingController _searchController = TextEditingController();

  // 缓存管理器
  late CacheManager _cacheManager;

  @override
  void initState() {
    super.initState();

    // 初始化缓存管理器
    _cacheManager =
        CacheManager(ref.read(ProviderManager.sharedPreferencesProvider));

    // 加载已缓存的歌曲
    _loadRecentPlays();

    // 初始化搜索结果为全部歌曲
    _filteredSongs = _songs;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// 加载已缓存的歌曲
  Future<void> _loadRecentPlays() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _songs.clear();
    });

    try {
      // 从缓存获取所有歌曲
      final cachedSongs = await _cacheManager.getAllCachedSongs();
      
      // 先显示所有缓存的歌曲
      setState(() {
        _songs.addAll(cachedSongs);
        _filteredSongs = _songs;
        _isLoading = false;
      });
      
      // 然后异步补充缺失的歌曲信息
      _enrichIncompleteData(cachedSongs);
    } catch (e) {
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }
  
  /// 补充不完整的歌曲信息
  Future<void> _enrichIncompleteData(List<PlaySongInfo> songs) async {
    if (songs.isEmpty) return;
    
    // 记录需要更新的歌曲索引
    List<int> indicesToUpdate = [];
    
    // 找出信息不完整的歌曲
    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];
      // 检查歌曲信息是否不完整
      if (song.title == '歌曲信息加载中...' || 
          song.title == '未知歌曲' || 
          song.artist == '未知歌手') {
        indicesToUpdate.add(i);
      }
    }
    
    // 没有需要更新的歌曲
    if (indicesToUpdate.isEmpty) return;
    
    print('共有 ${indicesToUpdate.length} 首歌曲需要补充信息');
    
    // 对于每个不完整的歌曲，尝试从API获取信息
    for (final index in indicesToUpdate) {
      if (!mounted) return; // 如果组件已经卸载，不再继续
      
      final song = _songs[index];
      try {
        // 获取歌曲详情
        final songDetail = await ref
            .read(ProviderManager.apiServiceProvider)
            .getSongDetail(song.hash);
            
        if (songDetail != null) {
          Map<String, dynamic> info;
          // 解析获取到的详情
          if (songDetail['data'] != null) {
            info = songDetail['data'];
          } else {
            info = songDetail;
          }
          
          // 提取字段
          final title = info['songname'] ?? 
                       info['song_name'] ?? 
                       info['filename'] ?? 
                       info['name'] ?? 
                       '未知歌曲';
                       
          final artist = info['singername'] ?? 
                        info['author_name'] ?? 
                        info['singerName'] ?? 
                        info['singer'] ?? 
                        info['author'] ?? 
                        '未知歌手';
                        
          final albumId = info['album_id'] ?? 
                        info['albumid'] ?? 
                        info['albumId'] ?? 
                        '';
                        
          final cover = info['album_img'] ?? 
                      info['img'] ?? 
                      info['imgUrl'] ?? 
                      info['image'] ?? 
                      info['pic'] ?? 
                      info['cover'] ?? 
                      '';
                        
          final mixsongid = info['mixsongid'] ?? 
                          info['mixSongId'] ?? 
                          info['songId'] ?? 
                          '';
          
          // 更新歌曲信息
          final updatedSong = PlaySongInfo(
            hash: song.hash,
            title: title.toString(),
            artist: artist.toString(),
            albumId: albumId?.toString() ?? '',
            cover: cover?.toString() ?? '',
            mixsongid: mixsongid?.toString() ?? '',
            duration: song.duration,
          );
          
          // 更新状态
          setState(() {
            _songs[index] = updatedSong;
            // 如果正在搜索，也更新搜索结果
            if (_isSearching) {
              final filteredIndex = _filteredSongs.indexWhere((s) => s.hash == song.hash);
              if (filteredIndex != -1) {
                _filteredSongs[filteredIndex] = updatedSong;
              }
            } else {
              _filteredSongs = _songs;
            }
          });
          
          // 缓存更新后的详细信息
          await _cacheManager.cacheSong(song.hash, songDetail);
          
          // 增加短暂延迟，避免API请求过快
          await Future.delayed(const Duration(milliseconds: 200));
        }
      } catch (e) {
        print('获取歌曲 ${song.hash} 详情失败: $e');
        // 错误不影响其他歌曲的获取
        continue;
      }
    }
  }

  /// 下拉刷新处理
  Future<void> _handleRefresh() async {
    await _loadRecentPlays();
    return Future.value();
  }

  /// 播放歌曲
  Future<void> _playSong(PlaySongInfo song, int index) async {
    // 如果正在播放，则暂停
    final playerService = ref.read(ProviderManager.playerServiceProvider);
    final isPlaying = playerService.isPlaying &&
        playerService.currentSongInfo?.hash == song.hash;

    if (isPlaying) {
      playerService.pause();
      return;
    }

    try {
      // 准备播放列表
      playerService.preparePlaylist(_filteredSongs, index);

      // 如果歌曲缺少albumId，尝试获取完整信息
      if (song.albumId == null || song.albumId!.isEmpty) {
        setState(() {
          _isLoading = true;
        });

        try {
          // 获取歌曲详情
          final songDetail = await ref
              .read(ProviderManager.apiServiceProvider)
              .getSongDetail(song.hash);

          if (songDetail != null) {
            final info = songDetail['data'] ?? songDetail;
            final albumId = info['album_id'] ?? '';

            // 更新歌曲信息
            final updatedSong = PlaySongInfo(
              hash: song.hash,
              title: song.title,
              artist: song.artist,
              albumId: albumId,
              cover: song.cover,
              mixsongid: song.mixsongid,
              duration: song.duration,
            );

            // 更新列表中的歌曲
            setState(() {
              _filteredSongs[index] = updatedSong;
              if (index < _songs.length) {
                _songs[_songs.indexWhere((s) => s.hash == song.hash)] =
                    updatedSong;
              }
            });

            // 播放更新后的歌曲
            playerService.preparePlaylist(_filteredSongs, index);
            await playerService.play(updatedSong);
          } else {
            // 如果无法获取详情，仍尝试播放原始歌曲
            await playerService.play(song);
          }
        } catch (e) {
          print('获取歌曲详情失败: $e');
          // 尝试直接播放
          await playerService.play(song);
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        // 直接播放歌曲
        await playerService.play(song);
      }
    } catch (e) {
      print('播放歌曲失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败: $e')),
      );
    }
  }

  // 显示搜索框
  void _showSearchBar() {
    setState(() {
      _isShowingSearchBar = !_isShowingSearchBar;
      if (!_isShowingSearchBar) {
        _clearSearch();
      }
    });
  }

  // 执行搜索
  void _performSearch(String query) {
    if (query.isEmpty) {
      _clearSearch();
      return;
    }

    setState(() {
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
      _filteredSongs = _songs;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final playerService = ref.watch(ProviderManager.playerServiceProvider);
    final currentPlayingSongHash = playerService.currentSongInfo?.hash;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('已缓存歌曲',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(_isShowingSearchBar ? Icons.search_off : Icons.search),
            tooltip: _isShowingSearchBar ? '关闭搜索' : '搜索歌曲',
            onPressed: () {
              _showSearchBar();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 搜索框，只在显示时才添加
          if (_isShowingSearchBar)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索歌曲或歌手',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: _performSearch,
              ),
            ),

          // 歌曲列表
          Expanded(
            child: _buildSongsList(currentPlayingSongHash),
          ),

          // 迷你播放器
          MiniPlayer(),
        ],
      ),
    );
  }

  /// 构建歌曲列表
  Widget _buildSongsList(String? currentPlayingSongHash) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text('加载失败: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRecentPlays,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_filteredSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSearching ? Icons.search_off : Icons.history_toggle_off,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              _isSearching ? '没有找到匹配的歌曲' : '暂无播放记录',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            if (!_isSearching) ...[
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _handleRefresh,
                child: Text('刷新'),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _filteredSongs.length,
        itemBuilder: (context, index) {
          final song = _filteredSongs[index];
          final isPlaying = song.hash == currentPlayingSongHash;

          return ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: song.cover != null && song.cover!.isNotEmpty
                  ? Image.network(
                      ImageUtils.getThumbnailUrl(song.cover),
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[200],
                          child:
                              Icon(Icons.music_note, color: Colors.grey[400]),
                        );
                      },
                    )
                  : Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[200],
                      child: Icon(Icons.music_note, color: Colors.grey[400]),
                    ),
            ),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isPlaying ? Colors.blue : Colors.black87,
                fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            trailing: IconButton(
              icon: Icon(
                isPlaying
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                color: isPlaying ? Colors.blue : Colors.grey,
              ),
              onPressed: () {
                _playSong(song, index);
              },
            ),
            onTap: () {
              _playSong(song, index);
            },
          );
        },
      ),
    );
  }
}
