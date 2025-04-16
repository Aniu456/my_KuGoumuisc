import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/play_song_info.dart';
import '../../core/providers/provider_manager.dart';
import '../../hooks/getTitle_ArtistName.dart';
import '../../services/player_service.dart';
import '../../utils/image_utils.dart';
import '../../features/player/player_page.dart';
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

  @override
  void initState() {
    super.initState();

    if (widget.playlistId != null) {
      _loadInitialSongs();
      _scrollController.addListener(_onScroll);
    } else if (widget.playlist != null) {
      setState(() {
        _songs.addAll(widget.playlist!);
        _hasMore = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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
        _hasMore = newSongs.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _isLoading = false;
      });
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
        .getPlaylistTracks(widget.playlistId!, page: page, pageSize: _pageSize);

    if (tracks.isEmpty) {
      return [];
    }

    return tracks.map((map) {
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
  }

  /// 下拉刷新处理
  Future<void> _handleRefresh() async {
    if (widget.playlistId != null) {
      await _loadInitialSongs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerService = ref.watch(ProviderManager.playerServiceProvider);
    final currentPlayingSongHash = playerService.currentSongInfo?.hash;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        elevation: 0, // 去掉阴影
        centerTitle: true, // 标题居中
      ),
      body: Column(
        children: [
          // 歌单列表（使用Expanded确保列表可以填充除MiniPlayer外的空间）
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

    return ListView.builder(
      controller: _scrollController,
      itemCount: _songs.length +
          (_isLoadingMore ? 1 : 0) +
          (!_hasMore && widget.playlistId != null && !_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 处理加载更多和没有更多的情况
        if (index == _songs.length) {
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

        final song = _songs[index];
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
                  playerService.preparePlaylist(_songs, index);
                  await playerService.play(song);
                  if (mounted) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const PlayerPage(),
                      ),
                    );
                  }
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
