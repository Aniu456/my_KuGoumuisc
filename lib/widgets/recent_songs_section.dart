import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recent_song.dart';
import '../models/play_song_info.dart';
import '../services/api_service.dart';
import '../services/player_service.dart';
import '../utils/image_utils.dart';
import '../pages/player_page.dart';
import 'music_list_screen.dart';

class RecentSongsSection extends StatefulWidget {
  const RecentSongsSection({super.key});

  @override
  State<RecentSongsSection> createState() => _RecentSongsSectionState();
}

class _RecentSongsSectionState extends State<RecentSongsSection> {
  List<RecentSong> _songs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.getRecentSongs();
      if (mounted) {
        setState(() {
          _songs = response.songs.take(20).toList();
          _isLoading = false;
        });
        print('已加载最近播放记录: ${_songs.length}首');
      }
    } catch (e) {
      print('加载最近播放记录失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _playSong(RecentSong recentSong) async {
    try {
      final playerService = context.read<PlayerService>();

      // 将最近播放列表转换为播放列表
      final playlist = _songs
          .map((recent) => PlaySongInfo(
                hash: recent.hash,
                title: recent.name,
                artist: recent.singername,
                cover: recent.cover,
                albumId: recent.albumId,
              ))
          .toList();

      // 找到当前歌曲在列表中的索引
      final currentIndex =
          _songs.indexWhere((song) => song.hash == recentSong.hash);

      // 先导航到播放页面
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PlayerPage(),
        ),
      );

      // 准备播放列表并开始播放
      playerService.preparePlaylist(playlist, currentIndex);
      await playerService.play(playlist[currentIndex]);
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
    return RefreshIndicator(
      onRefresh: _loadSongs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 13,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '最近播放',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MusicListScreen(
                          type: MusicListType.recent,
                          title: '最近播放',
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '更多',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 加载状态
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          // 空状态
          else if (_songs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.queue_music,
                      size: 32,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '暂无播放记录',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            )
          // 横向滚动的歌曲列表
          else
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                itemCount: _songs.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final song = _songs[index];
                  return SizedBox(
                    width: 72,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 封面图片
                        Stack(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.grey[100],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: song.cover.isNotEmpty
                                  ? Image.network(
                                      ImageUtils.getThumbnailUrl(song.cover),
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Icon(
                                          Icons.music_note,
                                          color: Colors.grey[400],
                                          size: 24,
                                        );
                                      },
                                    )
                                  : Icon(
                                      Icons.music_note,
                                      color: Colors.grey[400],
                                      size: 24,
                                    ),
                            ),
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _playSong(song),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withOpacity(0.2),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 歌曲名
                        Text(
                          song.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // 歌手名
                        Text(
                          song.singername,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
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
