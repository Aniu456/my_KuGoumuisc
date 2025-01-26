import 'package:flutter/material.dart';
import '../models/song_cache.dart';
import '../services/audio_cache_manager.dart';
import '../services/player_service.dart';
import '../models/play_song_info.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../pages/player_page.dart';
import '../utils/image_utils.dart';

class LocalSongsPage extends StatefulWidget {
  const LocalSongsPage({super.key});

  @override
  State<LocalSongsPage> createState() => _LocalSongsPageState();
}

class _LocalSongsPageState extends State<LocalSongsPage> {
  List<SongCache> _cachedSongs = [];
  bool _isLoading = true;
  bool _sortByPlayCount = false;

  @override
  void initState() {
    super.initState();
    _loadCachedSongs();
  }

  Future<void> _loadCachedSongs() async {
    try {
      final cacheManager = await AudioCacheManager.getInstance();
      final songs = await cacheManager.getCachedSongs();

      if (mounted) {
        setState(() {
          _cachedSongs = songs;
          _sortSongs();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('加载本地歌曲失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _sortSongs() {
    if (_sortByPlayCount) {
      _cachedSongs.sort((a, b) => b.playCount.compareTo(a.playCount));
    } else {
      _cachedSongs.sort((a, b) => b.lastPlayTime.compareTo(a.lastPlayTime));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              '本地音乐',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            if (_cachedSongs.isNotEmpty)
              Text(
                '${_cachedSongs.length}首歌曲',
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
            icon: Icon(
              Icons.sort,
              size: 22,
              color: _sortByPlayCount
                  ? Theme.of(context).primaryColor
                  : Colors.black87,
            ),
            onPressed: () {
              setState(() {
                _sortByPlayCount = !_sortByPlayCount;
                _sortSongs();
              });
            },
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cachedSongs.isEmpty
              ? Center(
                  child: Text(
                    '暂无本地歌曲',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _cachedSongs.length,
                  itemBuilder: (context, index) {
                    final song = _cachedSongs[index];
                    return ListTile(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: ImageUtils.getThumbnailUrl(song.cover),
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[300],
                            child: const Icon(Icons.music_note, size: 24),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[300],
                            child: const Icon(Icons.music_note, size: 24),
                          ),
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist,
                        style: TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        '播放 ${song.playCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      onTap: () async {
                        // 播放歌曲
                        final playerService = context.read<PlayerService>();

                        // 将所有缓存歌曲转换为播放列表
                        final playlist = _cachedSongs
                            .map((song) => PlaySongInfo(
                                  hash: song.hash,
                                  title: song.title,
                                  artist: song.artist,
                                  cover: song.cover,
                                ))
                            .toList();

                        // 获取当前点击歌曲的索引
                        final currentIndex = _cachedSongs.indexOf(song);

                        // 设置播放列表
                        playerService.preparePlaylist(playlist, currentIndex);

                        // 播放当前选中的歌曲
                        final playInfo = playlist[currentIndex];
                        await playerService.play(playInfo);

                        // 跳转到播放页面
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PlayerPage(),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
    );
  }
}
