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

  @override
  void initState() {
    super.initState();
    _loadCachedSongs();
  }

  Future<void> _loadCachedSongs() async {
    try {
      final cacheManager = await AudioCacheManager.getInstance();
      final songs = await cacheManager.getCachedSongs();
      // 按最后播放时间排序
      songs.sort((a, b) => b.lastPlayTime.compareTo(a.lastPlayTime));

      if (mounted) {
        setState(() {
          _cachedSongs = songs;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '本地音乐',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadCachedSongs();
            },
          ),
        ],
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
                        final playInfo = PlaySongInfo(
                          hash: song.hash,
                          title: song.title,
                          artist: song.artist,
                          cover: song.cover,
                        );
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
