import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../models/song_mv.dart';
import '../services/player_service.dart';
import '../services/api_service.dart';
import 'package:marquee/marquee.dart';
import '../utils/image_utils.dart';
import 'video_player_page.dart';
import 'package:palette_generator/palette_generator.dart';
import 'dart:math';

// 歌词行类定义
class LyricLine {
  final String text;
  final Duration timestamp;

  LyricLine(this.text, this.timestamp);
}

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin {
  bool _showLyrics = false;
  String? _lyrics;
  final PageController _pageController = PageController();
  List<LyricLine> _lyricLines = [];
  int _currentLyricIndex = 0;
  int? _selectedLyricIndex;
  final ScrollController _lyricsScrollController = ScrollController();
  String? _currentSongHash;
  bool _isFavorite = false;
  final bool _isCheckingFavorite = false;
  int _currentPage = 0;
  List<MvInfo>? _mvList;
  bool _isLoadingMV = false;

  // 专辑封面颜色相关
  Color _dominantColor = Colors.pink;
  bool _isExtractingColors = false;

  // 添加动画控制器
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadLyricsIfNeeded();

    // 初始化动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // 页面加载完成后执行动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final playerService = context.watch<PlayerService>();
    final newHash = playerService.currentSongInfo?.hash;

    if (newHash != null && newHash != _currentSongHash) {
      _currentSongHash = newHash;
      _loadLyricsIfNeeded();
      _loadMVList();
      _extractDominantColor();
    }
  }

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _extractDominantColor() async {
    final playerService = context.read<PlayerService>();
    final currentSong = playerService.currentSongInfo;
    if (currentSong == null || currentSong.cover == null) return;

    if (_isExtractingColors) return;

    setState(() => _isExtractingColors = true);

    try {
      final imageUrl = ImageUtils.getLargeImageUrl(currentSong.cover!);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        NetworkImage(imageUrl),
        maximumColorCount: 20,
      );

      if (!mounted) return;

      // 优先使用鲜艳色调，如果没有则使用主色调
      final vibrantColor = paletteGenerator.vibrantColor?.color;
      final dominantColor = paletteGenerator.dominantColor?.color;

      setState(() {
        _dominantColor = vibrantColor ?? dominantColor ?? Colors.pink;
      });
    } catch (e) {
      print('提取颜色失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isExtractingColors = false);
      }
    }
  }

  Future<void> _loadLyricsIfNeeded() async {
    final playerService = context.read<PlayerService>();
    final apiService = context.read<ApiService>();

    if (playerService.currentSongInfo?.hash != null) {
      try {
        setState(() {
          _lyrics = null;
          _lyricLines = [];
        });

        final lyrics =
            await apiService.getFullLyric(playerService.currentSongInfo!.hash);

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

  Future<void> _toggleFavorite() async {
    final apiService = context.read<ApiService>();
    final playerService = context.read<PlayerService>();
    final currentSong = playerService.currentSongInfo;
    if (currentSong == null) return;
    // 添加收藏
    final success = await apiService.addToFavorite(currentSong);
    if (success && mounted) {
      setState(() => _isFavorite = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已添加到我喜欢'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

// 加载MV列表
  Future<void> _loadMVList() async {
    if (_isLoadingMV) return;

    final playerService = context.read<PlayerService>();
    final currentSong = playerService.currentSongInfo;
    if (currentSong == null) return;

    setState(() => _isLoadingMV = true);

    try {
      final apiService = context.read<ApiService>();
      final mvList = await apiService.getMVList(currentSong.mixsongid!);
      if (mounted) {
        setState(() => _mvList = mvList);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMV = false);
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
      case PlayMode.random:
        return Icons.shuffle;
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
    final currentSong = playerService.currentSongInfo;
    final isPlaying = playerService.isPlaying;
    final position = playerService.position;
    final duration = playerService.duration;
    final nextSong = playerService.nextSongInfo;

    if (currentSong == null) {
      return const Scaffold(
        body: Center(
          child: Text('没有正在播放的歌曲'),
        ),
      );
    }

    // 更新当前歌词
    _updateCurrentLyric(position);

    // 创建淡入动画
    final fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    return Scaffold(
      body: FadeTransition(
        opacity: fadeAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(
                ImageUtils.getLargeImageUrl(currentSong.cover ?? ''),
              ),
              fit: BoxFit.cover,
              onError: (_, __) {},
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: SafeArea(
                child: Column(
                  children: [
                    // 顶部导航栏
                    _buildAppBar(context, currentSong),

                    // 主要内容区
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (index) {
                          setState(() {
                            _showLyrics = index == 1;
                            _currentPage = index;
                          });
                        },
                        children: [
                          // 封面页
                          _buildCoverPage(context, currentSong),

                          // 歌词页
                          _buildLyricsPage(context),
                        ],
                      ),
                    ),

                    // 进度条
                    _buildWaveform(),

                    // 控制按钮
                    _buildControlButtons(context, isPlaying, playerService),

                    // 下一首歌曲预览
                    if (nextSong != null) _buildNextSongPreview(nextSong),

                    // 底部空白
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 顶部导航栏
  Widget _buildAppBar(BuildContext context, dynamic currentSong) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentSong.songName ?? '未知歌曲',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  currentSong.singerName ?? '未知歌手',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.white,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
    );
  }

  // 封面页
  Widget _buildCoverPage(BuildContext context, dynamic currentSong) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Hero(
          tag: 'player_fab',
          child: Container(
            width: MediaQuery.of(context).size.width * 0.75,
            height: MediaQuery.of(context).size.width * 0.75,
            margin: const EdgeInsets.symmetric(vertical: 16.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
              border:
                  Border.all(color: Colors.white.withOpacity(0.2), width: 4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                  MediaQuery.of(context).size.width * 0.375),
              child: Image.network(
                ImageUtils.getLargeImageUrl(currentSong.cover ?? ''),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[800],
                  child: const Icon(
                    Icons.music_note,
                    size: 80,
                    color: Colors.white54,
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 波形不再在这里显示，由主页面调用
        // _buildWaveform(),
      ],
    );
  }

  // 波形可视化效果
  Widget _buildWaveform() {
    final playerService = context.watch<PlayerService>();
    final position = playerService.position;
    final duration = playerService.duration;

    // 计算当前播放进度比例
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          // 波形图
          GestureDetector(
            onTapDown: (details) {
              // 点击直接跳转到指定位置
              _handleWaveformTouch(details.localPosition.dx);
            },
            onHorizontalDragStart: (details) {
              // 开始拖动时可以做一些视觉反馈
            },
            onHorizontalDragUpdate: (details) {
              // 拖动更新时修改播放进度
              _handleWaveformTouch(details.localPosition.dx);
            },
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.75,
              height: 50,
              child: Stack(
                clipBehavior: Clip.none, // 允许指示器超出容器范围
                children: [
                  // 波形背景
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(33, (index) {
                      // 计算柱状图相对位置
                      final double barPosition = index / 32.0;

                      // 创建随机高度的波形柱
                      double height = _getBarHeight(index);

                      // 确定颜色：已播放部分使用主色调，未播放部分使用灰色
                      final bool isPlayed = barPosition <= progress;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 3,
                        height: height,
                        decoration: BoxDecoration(
                          color: isPlayed
                              ? _getWaveColor(index)
                              : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),

                  // 进度指示器
                  Positioned(
                    left:
                        (MediaQuery.of(context).size.width * 0.75 * progress) -
                            2,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 指示器圆点
                  Positioned(
                    left:
                        (MediaQuery.of(context).size.width * 0.75 * progress) -
                            6,
                    bottom: -8,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _dominantColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _dominantColor.withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 时间显示
          Padding(
            padding: const EdgeInsets.only(top: 16.0, left: 10, right: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 处理波形图上的触摸事件
  void _handleWaveformTouch(double touchX) {
    final double waveformWidth = MediaQuery.of(context).size.width * 0.75;
    final double percent = (touchX / waveformWidth).clamp(0.0, 1.0);
    final playerService = context.read<PlayerService>();
    final duration = playerService.duration;

    if (duration.inMilliseconds > 0) {
      final int newPositionMs = (percent * duration.inMilliseconds).round();
      playerService.seek(Duration(milliseconds: newPositionMs));
    }
  }

  // 获取柱状图高度
  double _getBarHeight(int index) {
    if (!context.watch<PlayerService>().isPlaying) {
      return 20.0; // 非播放状态时显示统一高度
    }

    // 使用正弦波模拟音频波形
    final time = DateTime.now().millisecondsSinceEpoch / 500.0; // 控制动画速度
    final phase = index * 0.2; // 控制波形密度
    final amplitude = 20.0; // 基础振幅
    final offset = 20.0; // 基础高度偏移

    // 使用正弦函数生成波形
    final wave1 = sin(time + phase) * amplitude;
    final wave2 = sin(time * 1.5 + phase) * (amplitude * 0.5);
    final height = offset + wave1 + wave2;

    return height.clamp(10.0, 40.0); // 限制高度范围
  }

  // 获取不同波形柱的颜色
  Color _getWaveColor(int index) {
    final isPlaying = context.watch<PlayerService>().isPlaying;

    // 中心位置
    final centerIndex = 16;
    final distance = (index - centerIndex).abs();

    if (!isPlaying) {
      // 非播放状态时使用较暗的颜色
      return _dominantColor.withOpacity(0.3);
    }

    if (distance < 5) {
      return _dominantColor.withAlpha(255); // 中心部分使用主色调
    } else {
      // 渐变到浅色
      final opacity = 1.0 - (distance - 4) * 0.09; // 距离越远，越透明
      return _dominantColor.withOpacity(opacity.clamp(0.3, 1.0));
    }
  }

  // 歌词页
  Widget _buildLyricsPage(BuildContext context) {
    if (_lyrics == null || _lyricLines.isEmpty) {
      return const Center(
        child: Text(
          '暂无歌词',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      controller: _lyricsScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      itemCount: _lyricLines.length,
      itemBuilder: (context, index) {
        final bool isCurrent = index == _currentLyricIndex;
        final bool isSelected = index == _selectedLyricIndex;

        return GestureDetector(
          onTap: () {
            final playerService = context.read<PlayerService>();
            playerService.seek(_lyricLines[index].timestamp);
            setState(() => _selectedLyricIndex = index);
          },
          child: Container(
            height: 50,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            decoration: isSelected
                ? BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Text(
              _lyricLines[index].text,
              style: TextStyle(
                color: isCurrent ? Colors.white : Colors.white.withOpacity(0.6),
                fontSize: isCurrent ? 16 : 14,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  // 控制按钮
  Widget _buildControlButtons(
      BuildContext context, bool isPlaying, PlayerService playerService) {
    final playModeIcon = _getPlayModeIcon(playerService.playMode);
    final String playModeText = _getPlayModeText(playerService.playMode);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 播放模式说明
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            playModeText,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ),
        // 播放控制按钮
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 播放模式按钮
              IconButton(
                icon: Icon(playModeIcon, color: Colors.white, size: 24),
                onPressed: () {
                  playerService.togglePlayMode();
                  // 显示播放模式提示
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '已切换到${_getPlayModeText(playerService.playMode)}'),
                      duration: const Duration(seconds: 1),
                      backgroundColor: _dominantColor.withOpacity(0.8),
                    ),
                  );
                },
                tooltip: playModeText,
              ),
              // 上一曲按钮
              GestureDetector(
                onLongPress: () {
                  // 长按重新播放当前歌曲
                  if (playerService.currentSongInfo != null) {
                    playerService.seek(Duration.zero);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('重新播放当前歌曲'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: _dominantColor.withOpacity(0.8),
                      ),
                    );
                  }
                },
                child: IconButton(
                  icon: const Icon(Icons.skip_previous,
                      color: Colors.white, size: 32),
                  onPressed: playerService.canPlayPrevious
                      ? playerService.playPrevious
                      : () {
                          // 如果没有上一首，提示用户
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已经是第一首歌曲'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                ),
              ),
              // 播放/暂停按钮
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _dominantColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _dominantColor.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 2,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: playerService.togglePlay,
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
              // 下一曲按钮
              IconButton(
                icon:
                    const Icon(Icons.skip_next, color: Colors.white, size: 32),
                onPressed: playerService.canPlayNext
                    ? playerService.playNext
                    : () {
                        // 如果没有下一首，提示用户
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('已经是最后一首歌曲'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
              ),
              // 歌词/封面切换按钮
              IconButton(
                icon: Icon(
                  _showLyrics ? Icons.photo_size_select_actual : Icons.lyrics,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: _toggleLyricsView,
                tooltip: _showLyrics ? '切换到封面' : '切换到歌词',
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 获取播放模式对应的文本说明
  String _getPlayModeText(PlayMode mode) {
    switch (mode) {
      case PlayMode.loop:
        return '列表循环';
      case PlayMode.single:
        return '单曲循环';
      case PlayMode.sequence:
        return '顺序播放';
      case PlayMode.random:
        return '随机播放';
    }
  }

  // 下一首歌曲预览
  Widget _buildNextSongPreview(dynamic nextSong) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 歌曲封面
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: nextSong.cover != null
                ? Image.network(
                    ImageUtils.getThumbnailUrl(nextSong.cover),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white54,
                          size: 20,
                        ),
                      );
                    },
                  )
                : Container(
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.music_note,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
          ),

          const SizedBox(width: 16),

          // 歌曲信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nextSong.songName ?? '未知歌曲',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  nextSong.singerName ?? '未知歌手',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 时长
          Text(
            nextSong.duration != null
                ? _formatDuration(Duration(seconds: nextSong.duration!))
                : '--:--',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
          ),

          const SizedBox(width: 8),

          // 收藏按钮
          IconButton(
            icon: Icon(
              Icons.favorite_border,
              color: Colors.white.withOpacity(0.5),
              size: 20,
            ),
            onPressed: () async {
              final apiService = context.read<ApiService>();
              final success = await apiService.addToFavorite(nextSong);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已添加到我喜欢'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
