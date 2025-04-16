import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/provider_manager.dart';
import '../../data/models/play_song_info.dart';
import '../../utils/image_utils.dart';
import '../../hooks/getTitle_ArtistName.dart';

class NextSongCard extends ConsumerWidget {
  final PlaySongInfo nextSongInfo;
  final Color accentColor;

  const NextSongCard({
    super.key,
    required this.nextSongInfo,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            // 封面缩略图
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child:
                  nextSongInfo.cover != null && nextSongInfo.cover!.isNotEmpty
                      ? Image.network(
                          ImageUtils.getThumbnailUrl(nextSongInfo.cover),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.music_note,
                                color: Colors.black54, size: 24);
                          },
                        )
                      : const Icon(Icons.music_note,
                          color: Colors.black54, size: 24),
            ),

            // 歌曲信息
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '下一首',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          getSongTitle(nextSongInfo.title),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          getArtistName(nextSongInfo.title),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (nextSongInfo.duration != null)
                        Text(
                          ' • ${_formatDuration(_calculateSongDuration(nextSongInfo.duration!))}',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // 直接播放下一首按钮
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 24,
                icon: Icon(Icons.play_arrow_rounded, color: accentColor),
                onPressed: () {
                  // 点击直接播放下一首
                  ref.read(ProviderManager.playerServiceProvider).playNext();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 计算歌曲实际时长
  Duration _calculateSongDuration(int duration) {
    // 判断数值单位是秒还是毫秒
    if (duration > 10000) {
      // 如果值大于10000，很可能已经是毫秒了
      return Duration(milliseconds: duration);
    } else {
      // 否则认为是秒
      return Duration(seconds: duration);
    }
  }

  // 格式化时间
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
