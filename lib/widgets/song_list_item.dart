import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../services/player_service.dart';
import '../pages/player_page.dart';
import '../utils/image_utils.dart';

class SongListItem extends StatelessWidget {
  final Song song;
  final List<Song> playlist;
  final int index;

  const SongListItem({
    super.key,
    required this.song,
    required this.playlist,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        song.artists,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: ImageUtils.createCachedImage(
          ImageUtils.getThumbnailUrl(song.cover),
          width: 50,
          height: 50,
        ),
      ),
      onTap: () => _handleTap(context),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    try {
      final playerService = context.read<PlayerService>();

      // 先导航到播放页面
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const PlayerPage(),
        ),
      );

      // 准备播放列表和当前歌曲
      playerService.preparePlaylist(playlist, index);
      await playerService.setCurrentSong(song);

      // 开始播放
      await playerService.startPlayback();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('播放失败: $e')),
      );
    }
  }
}
