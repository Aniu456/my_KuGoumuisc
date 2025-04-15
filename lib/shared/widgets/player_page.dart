import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/image_utils.dart';
import '../../core/providers/provider_manager.dart';
import '../../data/models/play_song_info.dart';
import '../../services/player_service.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _showLyrics = false; // 控制是否显示歌词
  final ScrollController _lyricsScrollController =
      ScrollController(); // 歌词滚动控制器
  int _lastLyricIndex = -1; // 记录上一个歌词索引，用于判断是否需要滚动

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final playerService = ref.watch(ProviderManager.playerServiceProvider);
    final currentSong = playerService.currentSongInfo;
    final nextSong = playerService.nextSongInfo;
    final isPlaying = playerService.isPlaying;
    final position = playerService.position;
    final duration = playerService.duration;
    final lyricsText = playerService.lyrics;

    // 解析歌词
    final lyrics = parseLyrics(lyricsText);
    final currentLyricIndex = getCurrentLyricIndex(lyrics, position);

    if (currentSong == null) {
      return const Scaffold(
        body: Center(child: Text('没有正在播放的歌曲')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景图片和效果
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.deepPurple.shade900.withOpacity(0.8),
                    Colors.black,
                  ],
                ),
              ),
              child: currentSong.cover != null && currentSong.cover!.isNotEmpty
                  ? Stack(
                      children: [
                        // 背景图片
                        Opacity(
                          opacity: 0.4,
                          child: Image.network(
                            ImageUtils.getLargeUrl(currentSong.cover),
                            fit: BoxFit.cover,
                            height: double.infinity,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(color: Colors.black);
                            },
                          ),
                        ),
                        // 模糊效果
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                          child: Container(
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                      ],
                    )
                  : Container(color: Colors.black),
            ),
          ),

          // 主内容
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 顶部栏
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 返回按钮
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                        onPressed: () {
                          // 简单使用Navigator.pop，避免GoRouter的pop错误
                          Navigator.of(context).pop();
                        },
                      ),
                      // 标题
                      Text(
                        _showLyrics ? '正在播放' : currentSong.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // 切换歌词/封面按钮
                      IconButton(
                        icon: Icon(
                          _showLyrics ? Icons.album_outlined : Icons.lyrics,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          setState(() {
                            _showLyrics = !_showLyrics;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 主要内容区域 - 封面或歌词
                Expanded(
                  child: _showLyrics
                      ? _buildLyricsView(lyrics, currentLyricIndex, currentSong)
                      : _buildCoverAndWaveformView(
                          currentSong, isPlaying, position, duration),
                ),

                // 底部控制区域
                _buildControlSection(playerService, currentSong, nextSong,
                    isPlaying, position, duration),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建控制区域(底部)
  Widget _buildControlSection(
      PlayerService playerService,
      PlaySongInfo currentSong,
      PlaySongInfo? nextSong,
      bool isPlaying,
      Duration position,
      Duration duration) {
    return Column(
      children: [
        // 进度条
        _buildProgressBar(),

        // 播放控制按钮
        _buildPlayerControls(),

        // 下一首歌曲提示卡片
        if (nextSong != null)
          Padding(
            padding:
                const EdgeInsets.only(bottom: 10.0, left: 15.0, right: 15.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // 封面缩略图
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.grey[800],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: nextSong.cover != null && nextSong.cover!.isNotEmpty
                        ? Image.network(
                            ImageUtils.getThumbnailUrl(nextSong.cover),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.music_note,
                                  color: Colors.white);
                            },
                          )
                        : const Icon(Icons.music_note, color: Colors.white),
                  ),

                  // 歌曲信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '下一首: ${nextSong.title}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          nextSong.artist,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // 时长标签
                  if (nextSong.duration != null)
                    Text(
                      _formatDuration(Duration(seconds: nextSong.duration!)),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // 构建歌词显示视图
  Widget _buildLyricsView(
      List<LyricLine> lyrics, int currentIndex, PlaySongInfo currentSong) {
    // 当歌词索引变化时滚动到当前歌词
    if (currentIndex != _lastLyricIndex &&
        currentIndex >= 0 &&
        lyrics.isNotEmpty) {
      _lastLyricIndex = currentIndex;
      // 延迟滚动，确保布局完成
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_lyricsScrollController.hasClients) {
          _lyricsScrollController.animateTo(
            currentIndex * 38.0, // 估计每行高度为38像素
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: lyrics.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_note, size: 64, color: Colors.white30),
                  const SizedBox(height: 20),
                  Text(
                    '暂无歌词',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              controller: _lyricsScrollController,
              itemCount: lyrics.length,
              padding: const EdgeInsets.symmetric(vertical: 40),
              itemBuilder: (context, index) {
                final isCurrentLine = index == currentIndex;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  child: Text(
                    lyrics[index].text,
                    style: TextStyle(
                      color: isCurrentLine ? Colors.white : Colors.white60,
                      fontSize: isCurrentLine ? 20 : 16,
                      fontWeight:
                          isCurrentLine ? FontWeight.w600 : FontWeight.normal,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
    );
  }

  // 构建封面和波形图视图
  Widget _buildCoverAndWaveformView(PlaySongInfo currentSong, bool isPlaying,
      Duration position, Duration duration) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const Spacer(flex: 1),

          // 歌曲信息
          if (!_showLyrics)
            Text(
              currentSong.artist,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),

          const SizedBox(height: 30),

          // 专辑封面
          Hero(
            tag: 'album-cover',
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: RotationTransition(
                  turns: isPlaying
                      ? _controller
                      : AlwaysStoppedAnimation(_controller.value),
                  child:
                      currentSong.cover != null && currentSong.cover!.isNotEmpty
                          ? Image.network(
                              ImageUtils.getLargeUrl(currentSong.cover),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.music_note,
                                      size: 100, color: Colors.white54),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.music_note,
                                  size: 100, color: Colors.white54),
                            ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // 音频波形可视化图
          SizedBox(
            height: 40,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 40),
              painter: WaveformPainter(
                progress: duration.inMilliseconds > 0
                    ? (position.inMilliseconds / duration.inMilliseconds)
                        .clamp(0.0, 1.0)
                    : 0.0,
              ),
            ),
          ),

          const Spacer(flex: 1),
        ],
      ),
    );
  }

  // 格式化时间
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _buildProgressBar() {
    return Consumer(
      builder: (context, ref, child) {
        final playerService = ref.watch(ProviderManager.playerServiceProvider);
        final position = playerService.position;
        final duration = playerService.duration;

        // 确保进度值在有效范围内
        double progress = 0.0;
        if (duration.inMilliseconds > 0) {
          progress = position.inMilliseconds / duration.inMilliseconds;
          // 限制进度值在0.0到1.0之间
          progress = progress.clamp(0.0, 1.0);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 4.0,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12.0),
                activeTrackColor: Theme.of(context).primaryColor,
                inactiveTrackColor: Colors.grey[700],
                thumbColor: Theme.of(context).primaryColor,
                overlayColor: Theme.of(context).primaryColor.withAlpha(80),
              ),
              child: Slider(
                value: progress,
                min: 0.0,
                max: 1.0,
                onChanged: (value) {
                  // 避免设置无效的进度值
                  if (duration.inMilliseconds > 0) {
                    final newPosition = Duration(
                      milliseconds: (value * duration.inMilliseconds).round(),
                    );
                    ref
                        .read(ProviderManager.playerServiceProvider)
                        .seek(newPosition);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlayerControls() {
    return Consumer(
      builder: (context, ref, child) {
        final playerService = ref.watch(ProviderManager.playerServiceProvider);
        final isPlaying = playerService.isPlaying;
        final playMode = playerService.playMode;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              iconSize: 28,
              icon: Icon(
                _getPlayModeIcon(playMode),
                color: Colors.white,
              ),
              onPressed: () {
                ref
                    .read(ProviderManager.playerServiceProvider)
                    .togglePlayMode();
              },
            ),
            IconButton(
              iconSize: 32,
              icon: const Icon(Icons.skip_previous, color: Colors.white),
              onPressed: () {
                ref.read(ProviderManager.playerServiceProvider).playPrevious();
              },
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 38,
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                onPressed: () {
                  if (isPlaying) {
                    ref.read(ProviderManager.playerServiceProvider).pause();
                  } else {
                    ref.read(ProviderManager.playerServiceProvider).resume();
                  }
                },
              ),
            ),
            IconButton(
              iconSize: 32,
              icon: const Icon(Icons.skip_next, color: Colors.white),
              onPressed: () {
                ref.read(ProviderManager.playerServiceProvider).playNext();
              },
            ),
            IconButton(
              iconSize: 28,
              icon: const Icon(Icons.playlist_play, color: Colors.white),
              onPressed: () {
                // TODO: 实现播放列表查看
              },
            ),
          ],
        );
      },
    );
  }

  IconData _getPlayModeIcon(PlayMode playMode) {
    switch (playMode) {
      case PlayMode.loop:
        return Icons.repeat;
      case PlayMode.random:
        return Icons.shuffle;
      case PlayMode.single:
        return Icons.repeat_one;
      case PlayMode.sequence:
        return Icons.arrow_forward;
      default:
        throw Exception("Unknown play mode");
    }
  }
}

// 歌词行数据类
class LyricLine {
  final Duration time;
  final String text;

  LyricLine(this.time, this.text);
}

// 波形绘制器
class WaveformPainter extends CustomPainter {
  final double progress;

  WaveformPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final activePaint = Paint()
      ..color = Colors.blue.shade400
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    final inactivePaint = Paint()
      ..color = Colors.grey.shade700
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    // 生成随机高度的线条模拟波形图
    final barCount = 40;
    final barWidth = size.width / barCount;
    final random = math.Random(42); // 固定种子，确保每次绘制的波形相同

    for (var i = 0; i < barCount; i++) {
      // 随机生成高度
      final normalizedHeight = 0.3 + (random.nextDouble() * 0.7);
      final barHeight = normalizedHeight * size.height;

      // 确定是否使用活跃颜色
      final progressPosition = i / barCount;
      final isActive = progressPosition <= progress;

      // 绘制线条
      canvas.drawLine(
        Offset(i * barWidth, size.height / 2 - barHeight / 2),
        Offset(i * barWidth, size.height / 2 + barHeight / 2),
        isActive ? activePaint : inactivePaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
