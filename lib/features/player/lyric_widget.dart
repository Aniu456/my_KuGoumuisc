import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
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

class _LyricWidgetState extends ConsumerState<LyricWidget>
    with TickerProviderStateMixin {
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastLyricIndex = -1;
  bool _userScrolling = false;
  Timer? _scrollResumeTimer;

  // 歌词行高度参数
  static const double _baseLineHeight = 60.0; // 基础行高估计值
  static const double _positionRatio = 0.5; // 当前歌词在屏幕上的位置比例（0.5为正中间）

  // 用于存储每行歌词的实际高度
  final Map<int, double> _lineHeights = {};
  final GlobalKey _listViewKey = GlobalKey();

  @override
  void dispose() {
    _scrollResumeTimer?.cancel();
    _lyricsScrollController.removeListener(_onScrollChanged);
    _lyricsScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // 添加滚动监听器，检测用户手动滚动
    _lyricsScrollController.addListener(_onScrollChanged);

    // 初始化完成后滚动到当前歌词
    // 使用两个延迟来确保视图已经完全构建
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 第一次延迟确保 ListView 已经渲染
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          // 测量行高
          _measureLineHeights();

          // 第二次延迟确保测量完成
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              // 使用jumpTo而不是animateTo来避免动画问题
              _scrollToCurrentLyric(immediate: true);
            }
          });
        }
      });
    });
  }

  // 监听滚动变化
  void _onScrollChanged() {
    // 如果滚动正在进行，标记为用户滚动
    if (_lyricsScrollController.position.isScrollingNotifier.value) {
      _userScrolling = true;
      _scrollResumeTimer?.cancel();
    } else if (_userScrolling) {
      // 用户滚动结束后，设置延迟恢复自动滚动
      _scrollResumeTimer?.cancel();
      _scrollResumeTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _userScrolling = false;
            // 重新测量行高并恢复自动滚动
            _measureLineHeights();
            _scrollToCurrentLyric();
          });
        }
      });
    }
  }

  // 计算每行歌词的位置和高度
  double _calculateLineOffset(int index) {
    double offset = 0;

    // 计算当前行之前所有行的高度总和
    for (int i = 0; i < index; i++) {
      offset += _lineHeights[i] ?? _baseLineHeight;
    }

    return offset;
  }

  // 滚动到当前歌词并优化显示位置
  void _scrollToCurrentLyric({bool immediate = false}) {
    // 如果用户正在滚动且不是强制滚动，则不打断用户操作
    if (_userScrolling && !immediate) {
      return;
    }

    // 确保列表已经构建且有有效的歌词索引
    if (widget.currentIndex >= 0 &&
        widget.lyrics.isNotEmpty &&
        _lyricsScrollController.hasClients) {
      // 获取可视区域高度
      final double viewportHeight =
          _lyricsScrollController.position.viewportDimension;

      // 计算当前行的偏移量
      final double currentLineOffset =
          _calculateLineOffset(widget.currentIndex);

      // 获取当前行的高度
      final double currentLineHeight =
          _lineHeights[widget.currentIndex] ?? _baseLineHeight;

      // 计算目标滚动位置，使当前歌词在屏幕的指定位置
      // 使用 _positionRatio 来控制当前歌词在屏幕上的位置（0.5为中间，越小越靠上）
      final double targetPosition = currentLineOffset -
          (viewportHeight * _positionRatio) +
          (currentLineHeight / 2);

      // 防止超出范围
      final double maxScroll = _lyricsScrollController.position.maxScrollExtent;
      final double minScroll = 0.0;
      final double safePosition = targetPosition.clamp(minScroll, maxScroll);

      // 执行滚动动画，使用更自然的曲线
      if (immediate) {
        // 对于即时滚动，使用jumpTo而不是animateTo
        _lyricsScrollController.jumpTo(safePosition);
      } else {
        _lyricsScrollController.animateTo(
          safePosition,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
        );
      }
    }
  }

  // 测量歌词行高度
  void _measureLineHeights() {
    // 确保视图已经构建
    if (!_lyricsScrollController.hasClients) return;

    // 清除旧的高度缓存
    _lineHeights.clear();

    // 获取ListView的RenderObject
    final RenderObject? listViewRenderObject =
        _listViewKey.currentContext?.findRenderObject();
    if (listViewRenderObject == null) return;

    // 遍历所有可见的歌词行
    for (int i = 0; i < widget.lyrics.length; i++) {
      // 查找每行的RenderObject
      final BuildContext? lineContext = _findLineContext(i);
      if (lineContext == null) continue;

      final RenderObject? lineRenderObject = lineContext.findRenderObject();
      if (lineRenderObject == null) continue;

      // 计算行高
      final Size lineSize = lineRenderObject.paintBounds.size;
      _lineHeights[i] = lineSize.height;
    }
  }

  // 查找特定行的BuildContext
  BuildContext? _findLineContext(int index) {
    try {
      // 这是一个简化的实现，实际上可能需要更复杂的查找逻辑
      final BuildContext? listViewContext = _listViewKey.currentContext;
      if (listViewContext == null) return null;

      // 在实际应用中，你可能需要使用更复杂的方法来查找子元素
      // 这里简单返回null，因为我们会在滚动后重新测量
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 当歌词索引变化时滚动到当前歌词
    if (widget.currentIndex != _lastLyricIndex &&
        widget.currentIndex >= 0 &&
        widget.lyrics.isNotEmpty) {
      _lastLyricIndex = widget.currentIndex;

      // 使用微任务而不是延迟，提高响应速度
      Future.microtask(() {
        if (mounted) {
          // 先测量行高，然后滚动
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _measureLineHeights();
            _scrollToCurrentLyric();
          });
        }
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
                    key: _listViewKey,
                    controller: _lyricsScrollController,
                    itemCount: widget.lyrics.length,
                    // 添加足够的内边距使歌词可以在屏幕上下滚动到指定位置
                    padding: EdgeInsets.symmetric(
                      vertical: MediaQuery.of(context).size.height * 0.45,
                    ),
                    itemBuilder: (context, index) {
                      final isCurrentLine = index == widget.currentIndex;
                      // 计算与当前行的距离，用于渐变效果
                      final int distance = (index - widget.currentIndex).abs();
                      final double opacityFactor = distance == 0
                          ? 1.0
                          : distance == 1
                              ? 0.8
                              : distance == 2
                                  ? 0.6
                                  : distance >= 3
                                      ? 0.4
                                      : 0.3;

                      return GestureDetector(
                        onTap: () {
                          // 点击歌词跳转到对应时间
                          if (index < widget.lyrics.length) {
                            final playerService =
                                ref.read(ProviderManager.playerServiceProvider);
                            playerService.seek(widget.lyrics[index].time);

                            // 取消任何待定的恢复计时器
                            _scrollResumeTimer?.cancel();

                            // 短暂禁用自动滚动，但在短时间后恢复
                            _userScrolling = true;
                            _scrollResumeTimer =
                                Timer(const Duration(milliseconds: 500), () {
                              if (mounted) {
                                setState(() {
                                  _userScrolling = false;
                                  // 将点击的歌词滚动到指定位置
                                  _scrollToCurrentLyric();
                                });
                              }
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 300),
                            style: TextStyle(
                              color: isCurrentLine
                                  ? widget.accentColor
                                  : Colors.black54
                                      .withAlpha((opacityFactor * 255).toInt()),
                              fontSize: isCurrentLine ? 18 : 16,
                              fontWeight: isCurrentLine
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              height: 1.3,
                            ),
                            child: Text(
                              widget.lyrics[index].text,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 3,
                            ),
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

// 获取当前应该显示的歌词索引
int getCurrentLyricIndex(List<LyricLine> lyrics, Duration position) {
  if (lyrics.isEmpty) return -1;

  // 找到最后一个时间小于当前位置的歌词
  for (int i = lyrics.length - 1; i >= 0; i--) {
    if (lyrics[i].time <= position) {
      // 添加一个小容差，避免在歌词边界处频繁切换
      final bool isLastLine = i == lyrics.length - 1;
      if (isLastLine) {
        return i;
      }

      // 检查是否接近下一行的时间点
      final nextLineTime = lyrics[i + 1].time;
      final currentLineTime = lyrics[i].time;
      final timeDifference =
          nextLineTime.inMilliseconds - currentLineTime.inMilliseconds;
      final threshold = timeDifference * 0.1; // 10%的容差

      // 如果非常接近下一行（在10%容差范围内），则提前显示下一行
      if (position.inMilliseconds > nextLineTime.inMilliseconds - threshold) {
        return i + 1;
      }

      return i;
    }
  }

  return -1;
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
