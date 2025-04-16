import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/provider_manager.dart';
import '../../data/models/play_song_info.dart';

// 歌词行数据类
class LyricLine {
  final Duration time;
  final String text;

  LyricLine(this.time, this.text);
}

//歌词页面歌词
class LyricWidget extends ConsumerStatefulWidget {
  final List<LyricLine> lyrics;
  final int currentIndex;
  final PlaySongInfo currentSong;
  final Color accentColor;
  final Function onClose;

  const LyricWidget({
    super.key,
    required this.lyrics,
    required this.currentIndex,
    required this.currentSong,
    required this.accentColor,
    required this.onClose,
  });

  @override
  ConsumerState<LyricWidget> createState() => _LyricWidgetState();
}

class _LyricWidgetState extends ConsumerState<LyricWidget> {
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastLyricIndex = -1;

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 初始化时滚动到当前歌词
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrentLyric();
    });
  }

  // 滚动到当前歌词并居中显示
  void _scrollToCurrentLyric() {
    if (widget.currentIndex >= 0 &&
        widget.lyrics.isNotEmpty &&
        _lyricsScrollController.hasClients) {
      // 估计每行高度（包括文本高度和内边距）
      const double estimatedLineHeight = 60.0; // 增加行高以适应多行歌词
      // 获取可视区域高度
      final double viewportHeight =
          _lyricsScrollController.position.viewportDimension;
      // 计算滚动位置，使当前歌词居中且留出更多空间
      final double scrollOffset = (widget.currentIndex * estimatedLineHeight) -
          (viewportHeight / 3); // 调整位置，使当前歌词在可视区域的上部三分之一处
      // 确保滚动位置不低于0
      final double normalizedOffset = scrollOffset < 0 ? 0 : scrollOffset;

      _lyricsScrollController.animateTo(
        normalizedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 当歌词索引变化时滚动到当前歌词
    if (widget.currentIndex != _lastLyricIndex &&
        widget.currentIndex >= 0 &&
        widget.lyrics.isNotEmpty) {
      _lastLyricIndex = widget.currentIndex;
      // 延迟滚动，确保布局完成
      Future.delayed(const Duration(milliseconds: 150), () {
        _scrollToCurrentLyric();
      });
    }

    return GestureDetector(
      // 添加垂直滑动手势关闭歌词页面
      onVerticalDragEnd: (details) {
        // 如果是向下滑动且速度足够，则关闭歌词页面
        if (details.velocity.pixelsPerSecond.dy > 200) {
          widget.onClose();
        }
      },
      child: Stack(
        children: [
          Container(
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: widget.lyrics.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.music_note,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 20),
                        Text(
                          '暂无歌词',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _lyricsScrollController,
                    itemCount: widget.lyrics.length,
                    padding: const EdgeInsets.symmetric(vertical: 120),
                    itemBuilder: (context, index) {
                      final isCurrentLine = index == widget.currentIndex;
                      return GestureDetector(
                        onTap: () {
                          // 点击歌词跳转到对应时间
                          if (index < widget.lyrics.length) {
                            final playerService =
                                ref.read(ProviderManager.playerServiceProvider);
                            playerService.seek(widget.lyrics[index].time);
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: Text(
                            widget.lyrics[index].text,
                            style: TextStyle(
                              color: isCurrentLine
                                  ? widget.accentColor
                                  : Colors.black54,
                              fontSize: isCurrentLine ? 18 : 16,
                              fontWeight: isCurrentLine
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              height: 1.3,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // 添加更明显的返回指示器
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white,
                    Colors.white.withAlpha(204), // 0.8 * 255 = 204
                    Colors.white.withAlpha(0),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // 线条指示器
                  GestureDetector(
                    // 添加垂直滑动手势，使用这个指示器也可以关闭歌词页面
                    onVerticalDragEnd: (details) {
                      if (details.velocity.pixelsPerSecond.dy > 100) {
                        widget.onClose();
                      }
                    },
                    // 点击指示器也可以关闭歌词页面
                    onTap: () => widget.onClose(),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '下滑关闭歌词',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//专辑下方歌词
class MiniLyricWidget extends StatelessWidget {
  final List<LyricLine> lyrics;
  final int currentIndex;
  final Duration position;
  final Color accentColor;
  final VoidCallback onTap;

  const MiniLyricWidget({
    super.key,
    required this.lyrics,
    required this.currentIndex,
    required this.position,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 如果没有歌词，显示简洁提示
    if (lyrics.isEmpty) {
      return GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '暂无歌词，点击查看',
            style: TextStyle(
              color: accentColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // 获取当前和接下来两行歌词
    String currentLyric = currentIndex >= 0 && currentIndex < lyrics.length
        ? lyrics[currentIndex].text
        : '';

    String nextLyric = currentIndex >= 0 && currentIndex + 1 < lyrics.length
        ? lyrics[currentIndex + 1].text
        : '';

    String thirdLyric = currentIndex >= 0 && currentIndex + 2 < lyrics.length
        ? lyrics[currentIndex + 2].text
        : '';

    // 不需要手动限制歌词长度，使用 TextOverflow.ellipsis 处理溢出

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            // 当前歌词
            Text(
              currentLyric,
              style: TextStyle(
                color: accentColor,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // 下一行歌词
            Text(
              nextLyric,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // 第三行歌词
            Text(
              thirdLyric,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// 解析LRC格式歌词
List<LyricLine> parseLyrics(String? lyricsText) {
  if (lyricsText == null || lyricsText.isEmpty) {
    return [];
  }

  final List<LyricLine> lyrics = [];
  final regExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2})\](.*)');

  for (var line in lyricsText.split('\n')) {
    if (line.trim().isEmpty) continue;

    final matches = regExp.allMatches(line);
    for (var match in matches) {
      if (match.groupCount >= 4) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds = int.parse(match.group(3)!) * 10; // 转换为毫秒
        final text = match.group(4)!.trim();

        final time = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        lyrics.add(LyricLine(time, text));
      }
    }
  }

  // 按时间排序
  lyrics.sort((a, b) => a.time.compareTo(b.time));
  return lyrics;
}

// 获取当前应该显示的歌词索引
int getCurrentLyricIndex(List<LyricLine> lyrics, Duration position) {
  if (lyrics.isEmpty) return -1;

  // 找到最后一个时间小于当前位置的歌词
  for (int i = lyrics.length - 1; i >= 0; i--) {
    if (lyrics[i].time <= position) {
      return i;
    }
  }

  return -1;
}
