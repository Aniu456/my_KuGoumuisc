import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import 'package:marquee/marquee.dart';
import '../utils/image_utils.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  IconData _getPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.loop:
        return Icons.repeat;
      case PlayMode.single:
        return Icons.repeat_one;
      case PlayMode.sequence:
        return Icons.sync;
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerService = context.watch<PlayerService>();
    final currentSong = playerService.currentSong;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(16, 17, 30, 1),
      body: Stack(
        children: [
          // 白色背景部分
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.5,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
            ),
          ),
          // 主要内容
          SafeArea(
            child: Column(
              children: [
                // 顶部导航栏
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // 只处理导航，不影响播放状态
                          Navigator.pop(context);
                        },
                        child: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white, size: 48),
                      ),
                      const Icon(Icons.more_horiz,
                          color: Colors.white, size: 48),
                    ],
                  ),
                ),
                // 歌曲信息
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 32,
                        child: currentSong != null
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  // 测量文本宽度
                                  final textSpan = TextSpan(
                                    text: currentSong.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                  final textPainter = TextPainter(
                                    text: textSpan,
                                    textDirection: TextDirection.ltr,
                                  )..layout(maxWidth: double.infinity);

                                  // 如果文本宽度超过容器宽度，使用Marquee
                                  if (textPainter.width >
                                      constraints.maxWidth) {
                                    return Marquee(
                                      text: currentSong.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      scrollAxis: Axis.horizontal,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      blankSpace: 80.0,
                                      velocity: 30.0,
                                      pauseAfterRound:
                                          const Duration(seconds: 2),
                                      startPadding: 10.0,
                                    );
                                  }

                                  // 否则使用普通Text
                                  return Text(
                                    currentSong.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              )
                            : const SizedBox(),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 24,
                        child: currentSong != null
                            ? LayoutBuilder(
                                builder: (context, constraints) {
                                  // 测量文本宽度
                                  final textSpan = TextSpan(
                                    text: currentSong.artists,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 18,
                                    ),
                                  );
                                  final textPainter = TextPainter(
                                    text: textSpan,
                                    textDirection: TextDirection.ltr,
                                  )..layout(maxWidth: double.infinity);

                                  // 如果文本宽度超过容器宽度，使用Marquee
                                  if (textPainter.width >
                                      constraints.maxWidth) {
                                    return Marquee(
                                      text: currentSong.artists,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 18,
                                      ),
                                      scrollAxis: Axis.horizontal,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      blankSpace: 80.0,
                                      velocity: 30.0,
                                      pauseAfterRound:
                                          const Duration(seconds: 2),
                                      startPadding: 10.0,
                                    );
                                  }

                                  // 否则使用普通Text
                                  return Text(
                                    currentSong.artists,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 18,
                                    ),
                                  );
                                },
                              )
                            : const SizedBox(),
                      ),
                    ],
                  ),
                ),
                // 专辑封面
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: screenWidth - 64,
                        height: screenWidth - 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(screenWidth / 20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 30,
                              offset: const Offset(0, 15),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(screenWidth / 20),
                          child: Image.network(
                            ImageUtils.getLargeUrl(currentSong?.cover ?? ''),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[100],
                                child: const Icon(
                                  Icons.music_note,
                                  size: 80,
                                  color: Colors.black12,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 底部控制区
                Container(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
                  child: Column(
                    children: [
                      // 功能按钮
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon:
                                Icon(_getPlayModeIcon(playerService.playMode)),
                            iconSize: 32,
                            color: Colors.black87,
                            onPressed: () => playerService.togglePlayMode(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite_border),
                            iconSize: 32,
                            color: Colors.black87,
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.queue_music),
                            iconSize: 32,
                            color: Colors.black87,
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 进度条
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                          activeTrackColor: Colors.black,
                          inactiveTrackColor: Colors.black12,
                          thumbColor: Colors.black,
                          overlayColor: Colors.black12,
                        ),
                        child: Slider(
                          value: playerService.position.inSeconds.toDouble(),
                          max: playerService.duration.inSeconds.toDouble(),
                          onChanged: (value) {
                            playerService
                                .seek(Duration(seconds: value.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(playerService.position),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _formatDuration(playerService.duration),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 播放控制
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            iconSize: 52,
                            color: Colors.black87,
                            onPressed: playerService.canPlayPrevious
                                ? () => playerService.playPrevious()
                                : null,
                          ),
                          const SizedBox(width: 48),
                          Container(
                            width: 88,
                            height: 77,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                playerService.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: const Color(0xFFE8D5B5),
                                size: 48,
                              ),
                              onPressed: () async {
                                if (playerService.currentSong != null) {
                                  await playerService.togglePlay();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 48),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            iconSize: 52,
                            color: Colors.black87,
                            onPressed: playerService.canPlayNext
                                ? () => playerService.playNext()
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
