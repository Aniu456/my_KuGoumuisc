import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../services/player_service.dart';
import '../services/api_service.dart';
import 'package:marquee/marquee.dart';
import '../utils/image_utils.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  bool _showLyrics = false;
  String? _lyrics;
  final PageController _pageController = PageController();
  List<LyricLine> _lyricLines = [];
  int _currentLyricIndex = 0;
  int? _selectedLyricIndex;
  final ScrollController _lyricsScrollController = ScrollController();
  String? _currentSongHash;

  @override
  void initState() {
    super.initState();
    _loadLyricsIfNeeded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playerService = context.watch<PlayerService>();
    final newHash = playerService.currentSong?.hash;

    if (newHash != null && newHash != _currentSongHash) {
      _currentSongHash = newHash;
      _loadLyricsIfNeeded();
    }
  }

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLyricsIfNeeded() async {
    final playerService = context.read<PlayerService>();
    final apiService = context.read<ApiService>();

    if (playerService.currentSong?.hash != null) {
      try {
        setState(() {
          _lyrics = null;
          _lyricLines = [];
        });

        final lyrics =
            await apiService.getFullLyric(playerService.currentSong!.hash);

        if (!mounted) return;

        setState(() {
          _lyrics = lyrics;
          _lyricLines = _parseLyrics(lyrics);
          _currentLyricIndex = 0;
          _selectedLyricIndex = null;
        });
      } catch (e) {
        print('加载歌词失败: $e');
        if (!mounted) return;

        setState(() {
          _lyrics = null;
          _lyricLines = [];
        });
      }
    }
  }

  void _updateCurrentLyric(Duration position) {
    if (_lyricLines.isEmpty) return;

    // 找到当前时间对应的歌词行
    int index = _lyricLines.indexWhere((line) => line.timestamp > position);
    if (index == -1) {
      // 如果没找到，说明是最后一行
      index = _lyricLines.length - 1;
    } else if (index > 0) {
      // 找到当前行的前一行
      index = index - 1;
    }

    if (index != _currentLyricIndex) {
      setState(() {
        _currentLyricIndex = index;
      });

      // 自动滚动到当前歌词
      if (_showLyrics && _lyricsScrollController.hasClients) {
        final offset = index * 50.0; // 每行高度50
        final maxScroll = _lyricsScrollController.position.maxScrollExtent;
        final minScroll = _lyricsScrollController.position.minScrollExtent;

        // 确保滚动位置在有效范围内
        final targetOffset = offset.clamp(minScroll, maxScroll);

        _lyricsScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _toggleLyricsView() {
    setState(() {
      _showLyrics = !_showLyrics;
      if (_showLyrics) {
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  List<LyricLine> _parseLyrics(String rawLyrics) {
    final lines = rawLyrics.split('\n');
    final List<LyricLine> result = [];

    // 跳过元数据行
    int startIndex = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('[id:') ||
          line.startsWith('[ar:') ||
          line.startsWith('[ti:') ||
          line.startsWith('[by:') ||
          line.startsWith('[hash:') ||
          line.startsWith('[al:') ||
          line.startsWith('[sign:') ||
          line.startsWith('[qq:') ||
          line.startsWith('[total:') ||
          line.startsWith('[offset:') ||
          line.startsWith('[length:')) {
        continue;
      }

      final timeMatches =
          RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]').allMatches(line);
      if (timeMatches.isEmpty) continue;

      // 提取歌词文本（去掉所有时间标签）
      String text =
          line.replaceAll(RegExp(r'\[\d{2}:\d{2}\.\d{2,3}\]'), '').trim();
      if (text.isEmpty) continue;

      // 为每个时间标签创建一个歌词行
      for (var match in timeMatches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = int.parse(match.group(2)!);
        final milliseconds =
            int.parse(match.group(3)!.padRight(3, '0')).toInt();

        final timestamp = Duration(
          minutes: minutes,
          seconds: seconds,
          milliseconds: milliseconds,
        );

        result.add(LyricLine(text, timestamp));
      }
    }

    // 按时间戳排序
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  List<String> _getPreviewLyrics() {
    if (_lyricLines.isEmpty) return [];

    final currentLine = _lyricLines[_currentLyricIndex].text;
    final nextLineIndex = _currentLyricIndex + 1;
    final nextLine = nextLineIndex < _lyricLines.length
        ? _lyricLines[nextLineIndex].text
        : '';

    return [currentLine, nextLine];
  }

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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final playerService = context.watch<PlayerService>();
    _updateCurrentLyric(playerService.position);
    final currentSong = playerService.currentSong;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _showLyrics = index == 1;
          });
        },
        children: [
          _buildPlayerPage(
              context, playerService, currentSong, screenWidth, screenHeight),
          _buildLyricsPage(context, currentSong),
        ],
      ),
    );
  }

  Widget _buildPlayerPage(BuildContext context, PlayerService playerService,
      currentSong, screenWidth, screenHeight) {
    return Stack(
      children: [
        // 背景图片层
        if (currentSong?.cover != null) ...[
          Positioned.fill(
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ImageUtils.createCachedImage(
                      ImageUtils.getLargeUrl(currentSong!.cover),
                      fit: BoxFit.cover,
                    ),
                  ),
                  // 模糊效果层
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.3),
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // 白色背景部分
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: MediaQuery.of(context).size.height * 0.55,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset: Offset(0, -4),
                ),
              ],
            ),
          ),
        ),

        // 主要内容
        SafeArea(
          child: Column(
            children: [
              // 顶部导航栏
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildIconButton(
                      Icons.keyboard_arrow_down,
                      () => Navigator.pop(context),
                      Colors.white,
                    ),
                    _buildIconButton(
                      Icons.more_horiz,
                      () {},
                      Colors.white,
                    ),
                  ],
                ),
              ),
              // 歌曲信息
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  children: [
                    SizedBox(
                      height: 32,
                      child: currentSong != null
                          ? _buildScrollingText(
                              currentSong.title,
                              const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            )
                          : const SizedBox(),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 24,
                      child: currentSong != null
                          ? _buildScrollingText(
                              currentSong.artists,
                              TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 18,
                                letterSpacing: 0.3,
                              ),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ),
              ),

              // 专辑封面
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Hero(
                          tag: 'album_cover',
                          child: Container(
                            width: screenWidth * 0.7,
                            height: screenWidth * 0.7,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(screenWidth * 0.06),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(screenWidth * 0.06),
                              child: ImageUtils.createCachedImage(
                                ImageUtils.getLargeUrl(
                                    currentSong?.cover ?? ''),
                                width: screenWidth * 0.7,
                                height: screenWidth * 0.7,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 歌词预览
                    GestureDetector(
                      onTap: _toggleLyricsView,
                      child: Container(
                        height: 60,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _lyrics != null && _lyricLines.isNotEmpty
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: _getPreviewLyrics()
                                    .map((line) => Text(
                                          line,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ))
                                    .toList(),
                              )
                            : const Center(
                                child: Text(
                                  '暂无歌词',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // 底部控制区
              Container(
                padding: EdgeInsets.fromLTRB(32, 0, 32, screenHeight * 0.05),
                child: Column(
                  children: [
                    // 功能按钮
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildControlButton(
                            _getPlayModeIcon(playerService.playMode),
                            () => playerService.togglePlayMode(),
                            color: Colors.black87,
                          ),
                          _buildControlButton(
                            Icons.favorite_border,
                            () {},
                            color: Colors.black87,
                          ),
                          _buildControlButton(
                            Icons.queue_music,
                            () {},
                            color: Colors.black87,
                          ),
                        ],
                      ),
                    ),

                    // 进度条
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                          pressedElevation: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                        activeTrackColor: Colors.black87,
                        inactiveTrackColor: Colors.black12,
                        thumbColor: Colors.black87,
                        overlayColor: Colors.black12,
                      ),
                      child: Slider(
                        value: playerService.position.inSeconds.toDouble(),
                        max: playerService.duration.inSeconds.toDouble(),
                        onChanged: (value) {
                          playerService.seek(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),

                    // 时间显示
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(playerService.position),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatDuration(playerService.duration),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 播放控制
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSkipButton(
                          Icons.skip_previous,
                          playerService.canPlayPrevious
                              ? () => playerService.playPrevious()
                              : null,
                          color: Colors.black87,
                        ),
                        _buildPlayPauseButton(
                          playerService.isPlaying,
                          () async {
                            if (playerService.currentSong != null) {
                              await playerService.togglePlay();
                            }
                          },
                        ),
                        _buildSkipButton(
                          Icons.skip_next,
                          playerService.canPlayNext
                              ? () => playerService.playNext()
                              : null,
                          color: Colors.black87,
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
    );
  }

  Widget _buildLyricsPage(BuildContext context, currentSong) {
    final playerService = context.watch<PlayerService>();
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: [
        // 背景
        if (currentSong?.cover != null) ...[
          Positioned.fill(
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ImageUtils.createCachedImage(
                      ImageUtils.getLargeUrl(currentSong!.cover),
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                      child: Container(
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        // 内容
        SafeArea(
          child: Column(
            children: [
              // 歌词内容
              Expanded(
                child: _lyrics != null && _lyricLines.isNotEmpty
                    ? ListView.builder(
                        controller: _lyricsScrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        itemCount: _lyricLines.length,
                        itemBuilder: (context, index) {
                          final line = _lyricLines[index];
                          final isCurrentLine = index == _currentLyricIndex;
                          final isSelected = index == _selectedLyricIndex;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedLyricIndex = isSelected ? null : index;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  if (isSelected)
                                    GestureDetector(
                                      onTap: () {
                                        playerService.seek(line.timestamp);
                                        setState(() {
                                          _selectedLyricIndex = null;
                                        });
                                      },
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.black87,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      line.text,
                                      style: TextStyle(
                                        color: isCurrentLine || isSelected
                                            ? Colors.white
                                            : Colors.white.withOpacity(0.5),
                                        fontSize: isCurrentLine || isSelected
                                            ? 18
                                            : 16,
                                        height: 1.5,
                                        fontWeight: isCurrentLine || isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      textAlign: isSelected
                                          ? TextAlign.left
                                          : TextAlign.center,
                                    ),
                                  ),
                                  if (isCurrentLine && !isSelected)
                                    Icon(
                                      Icons.music_note,
                                      color: Colors.white.withOpacity(0.7),
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Text(
                          '暂无歌词',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ),
              ),

              // 底部控制区
              Container(
                padding: EdgeInsets.fromLTRB(32, 0, 32, screenHeight * 0.05),
                child: Column(
                  children: [
                    // 进度条
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                          pressedElevation: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                        thumbColor: Colors.white,
                        overlayColor: Colors.white24,
                      ),
                      child: Slider(
                        value: playerService.position.inSeconds.toDouble(),
                        max: playerService.duration.inSeconds.toDouble(),
                        onChanged: (value) {
                          playerService.seek(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),

                    // 时间显示
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(playerService.position),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatDuration(playerService.duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 播放控制
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSkipButton(
                          Icons.skip_previous,
                          playerService.canPlayPrevious
                              ? () => playerService.playPrevious()
                              : null,
                          color: Colors.white,
                        ),
                        _buildPlayPauseButton(
                          playerService.isPlaying,
                          () async {
                            if (playerService.currentSong != null) {
                              await playerService.togglePlay();
                            }
                          },
                          isLyricPage: true,
                        ),
                        _buildSkipButton(
                          Icons.skip_next,
                          playerService.canPlayNext
                              ? () => playerService.playNext()
                              : null,
                          color: Colors.white,
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
    );
  }

  Widget _buildScrollingText(String text, TextStyle style) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textSpan = TextSpan(text: text, style: style);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: double.infinity);

        if (textPainter.width > constraints.maxWidth) {
          return Marquee(
            text: text,
            style: style,
            scrollAxis: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.center,
            blankSpace: 80.0,
            velocity: 35.0,
            pauseAfterRound: const Duration(seconds: 1),
            startPadding: 10.0,
            accelerationDuration: const Duration(seconds: 1),
            accelerationCurve: Curves.easeInOut,
            decelerationDuration: const Duration(milliseconds: 500),
            decelerationCurve: Curves.easeOut,
          );
        }

        return Text(
          text,
          style: style,
          textAlign: TextAlign.center,
        );
      },
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: color, size: 32),
        ),
      ),
    );
  }

  Widget _buildControlButton(IconData icon, VoidCallback onPressed,
      {Color color = Colors.white}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Icon(
            icon,
            color: color,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton(IconData icon, VoidCallback? onPressed,
      {Color color = Colors.white}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(32),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Icon(
            icon,
            color: onPressed != null ? color : color.withOpacity(0.38),
            size: 36,
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton(bool isPlaying, VoidCallback onPressed,
      {bool isLyricPage = false}) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLyricPage ? Colors.white : Colors.black87,
        boxShadow: [
          BoxShadow(
            color: (isLyricPage ? Colors.white : Colors.black).withOpacity(0.2),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: onPressed,
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: isLyricPage ? Colors.black87 : Colors.white,
            size: 42,
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons(PlayerService playerService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: _buildPlayModeIcon(playerService.playMode),
          onPressed: () {
            playerService.togglePlayMode();
            String modeText = '';
            switch (playerService.playMode) {
              case PlayMode.sequence:
                modeText = '顺序播放';
                break;
              case PlayMode.loop:
                modeText = '列表循环';
                break;
              case PlayMode.single:
                modeText = '单曲循环';
                break;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(modeText),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous),
          onPressed: () => playerService.playPrevious(),
        ),
        IconButton(
          icon: Icon(playerService.isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () {
            if (playerService.isPlaying) {
              playerService.pause();
            } else {
              playerService.resume();
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.skip_next),
          onPressed: () => playerService.playNext(),
        ),
        IconButton(
          icon: const Icon(Icons.playlist_play),
          onPressed: () {
            // TODO: 显示播放列表
          },
        ),
      ],
    );
  }

  Widget _buildPlayModeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.sequence:
        return const Icon(Icons.repeat_one_outlined);
      case PlayMode.loop:
        return const Icon(Icons.repeat);
      case PlayMode.single:
        return const Icon(Icons.repeat_one);
    }
  }
}

class LyricLine {
  final String text;
  final Duration timestamp;

  LyricLine(this.text, this.timestamp);
}
