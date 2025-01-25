import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recent_song.dart';
import '../services/api_service.dart';
import '../services/player_service.dart';
import '../utils/image_utils.dart';
import '../models/song.dart';
import '../pages/player_page.dart';
import '../pages/recent_songs_page.dart';

class RecentSongsSection extends StatefulWidget {
  const RecentSongsSection({super.key});

  @override
  State<RecentSongsSection> createState() => _RecentSongsSectionState();
}

class _RecentSongsSectionState extends State<RecentSongsSection>
    with AutomaticKeepAliveClientMixin {
  List<RecentSong> _recentSongs = [];
  bool _isFirstLoad = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 只在第一次加载时从缓存获取数据
    if (_isFirstLoad) {
      _isFirstLoad = false;
      _loadFromCache();
    }
  }

  // 从缓存加载数据
  Future<void> _loadFromCache() async {
    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.getRecentSongs();
      _updateSongsData(response);
    } catch (e) {
      print('从缓存加载最近播放失败: $e');
    }
  }

  // 从服务器刷新数据
  Future<void> _refreshFromServer() async {
    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.getRecentSongs(forceRefresh: true);
      _updateSongsData(response);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('刷新最近播放失败: $e')),
        );
      }
    }
  }

  // 更新歌曲数据
  void _updateSongsData(RecentSongsResponse response) {
    if (!mounted) return;
    setState(() {
      _recentSongs = response.songs;
    });
  }

  Future<void> _playSong(RecentSong recentSong) async {
    try {
      final playerService = context.read<PlayerService>();

      // 创建 Song 对象
      final song = Song(
        hash: recentSong.hash,
        name: '${recentSong.singername} - ${recentSong.songname}',
        cover: recentSong.cover,
        albumId: '',
        audioId: '',
        size: 0,
        singerName: recentSong.singername,
        albumImage: recentSong.cover,
      );

      // 先导航到播放页面
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PlayerPage(),
        ),
      );

      // 准备播放列表（这里只播放单曲）
      playerService.preparePlaylist([song], 0);
      await playerService.setCurrentSong(song);
      await playerService.startPlayback();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '最近播放',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecentSongsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // 最近播放列表
          if (_recentSongs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('暂无播放记录'),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _recentSongs.length,
                itemBuilder: (context, index) {
                  final song = _recentSongs[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 封面图片
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: ImageUtils.createCachedImage(
                                  ImageUtils.getMediumUrl(song.cover),
                                  width: 120,
                                  height: 120,
                                ),
                              ),
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _playSong(song),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // 歌曲名
                          Text(
                            song.songname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // 歌手名
                          Text(
                            song.singername,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
