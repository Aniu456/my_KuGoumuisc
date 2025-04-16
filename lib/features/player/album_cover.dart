import 'package:flutter/material.dart';
import '../../data/models/play_song_info.dart';
import '../../utils/image_utils.dart';

class AlbumCover extends StatelessWidget {
  final PlaySongInfo currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final Color accentColor;
  final Animation<double> rotationAnimation;

  const AlbumCover({
    super.key,
    required this.currentSong,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.accentColor,
    required this.rotationAnimation,
  });

  @override
  Widget build(BuildContext context) {
    // 获取屏幕宽度，用于计算合适的专辑封面大小
    double screenWidth = MediaQuery.of(context).size.width;
    // 专辑封面尺寸为屏幕宽度的75%
    double coverSize = screenWidth * 0.75; // 减小封面尺寸以留出更多空间给歌词

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          // 专辑封面
          Hero(
            tag: 'album-cover',
            child: Container(
              width: coverSize,
              height: coverSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child:
                      currentSong.cover != null && currentSong.cover!.isNotEmpty
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  ImageUtils.getLargeUrl(currentSong.cover),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Icon(Icons.music_note,
                                          size: 100, color: Colors.black38),
                                    );
                                  },
                                ),
                                // 播放状态指示器中心点
                                if (!isPlaying)
                                  Center(
                                    child: Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.play_arrow,
                                        size: 48,
                                        color: accentColor,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.music_note,
                                  size: 100, color: Colors.black38),
                            ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
