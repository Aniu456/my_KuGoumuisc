import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lyric_utils.dart'; // Import utility functions & LyricLine
import '../../data/models/play_song_info.dart';

/// Album bottom lyrics display widget showing three lines of lyrics
/// Each line can display up to two lines of text with ellipsis for overflow
class MiniLyricWidget extends ConsumerWidget {
  final List<LyricLine> lyrics;
  final Duration position;
  final PlaySongInfo currentSong;
  final Color accentColor;
  final Function() onTap;

  const MiniLyricWidget({
    super.key,
    required this.lyrics,
    required this.position,
    required this.currentSong,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 使用更精确的歌词索引计算
    final currentIndex = getCurrentLyricIndex(lyrics, position);

    String prevLyric = '';
    String currentLyric = '';
    String nextLyric = '';

    if (lyrics.isNotEmpty) {
      // 获取前一行歌词
      if (currentIndex > 0) {
        prevLyric = lyrics[currentIndex - 1].text;
      }

      // 获取当前歌词
      if (currentIndex >= 0 && currentIndex < lyrics.length) {
        currentLyric = lyrics[currentIndex].text;
      } else if (lyrics.isNotEmpty && position < lyrics.first.time) {
        // 如果在第一行歌词之前，显示第一行歌词
        currentLyric = lyrics.first.text;
      }

      // 获取下一行歌词
      if (currentIndex + 1 < lyrics.length) {
        nextLyric = lyrics[currentIndex + 1].text;
      } else if (currentIndex >= 0 && currentIndex == lyrics.length - 1) {
        // 如果是最后一行，下一行显示歌曲标题
        nextLyric = currentSong.title;
      }
    }

    // 如果没有歌词，显示默认文本
    if (lyrics.isEmpty ||
        (currentLyric.isEmpty && prevLyric.isEmpty && nextLyric.isEmpty)) {
      currentLyric = '暂无歌词';
      nextLyric = currentSong.title; // 显示歌曲标题作为后备
    }

    // 确保始终有三行显示
    if (prevLyric.isEmpty && currentLyric.isNotEmpty) {
      prevLyric = currentSong.artist; // 如果没有前一行，显示歌手名
    }

    if (nextLyric.isEmpty && currentLyric.isNotEmpty) {
      nextLyric = currentSong.title; // 如果没有下一行，显示歌曲标题
    }

    return GestureDetector(
      onTap: onTap, // 点击打开完整歌词
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        constraints: const BoxConstraints(minHeight: 110), // 确保有足够的高度显示三行歌词
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // 占用最小的垂直空间
          children: [
            // 前一行歌词（淡色）
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: prevLyric.isNotEmpty ? 1.0 : 0.0,
              child: Text(
                prevLyric,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.0,
                  color: Colors.black54.withAlpha(153), // 0.6 opacity (153/255)
                ),
              ),
            ),
            const SizedBox(height: 6.0),

            // 当前歌词（高亮）
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 17.0,
                fontWeight: FontWeight.w600,
                color: accentColor, // 高亮颜色
              ),
              child: Text(
                currentLyric,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6.0),

            // 下一行歌词（淡色）
            AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: nextLyric.isNotEmpty ? 1.0 : 0.0,
              child: Text(
                nextLyric,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.0,
                  color: Colors.black54.withAlpha(179), // 0.7 opacity (179/255)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
