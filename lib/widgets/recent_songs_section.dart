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

class _RecentSongsSectionState extends State<RecentSongsSection> {
  bool _isLoading = false;
  List<RecentSong> _recentSongs = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSongs();
  }

  Future<void> _loadRecentSongs() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.getRecentSongs();

      setState(() {
        _recentSongs = response.songs;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载最近播放失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_recentSongs.isEmpty)
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
