import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../core/providers/provider_manager.dart';
import '../../services/player_service.dart';
import '../../utils/image_utils.dart';
import 'album_cover.dart';
import 'lyric_widget.dart';
import 'lyric_utils.dart'; // Added import
import 'mini_lyric_widget.dart'; // Added import
import 'next_song_card.dart';
import 'player_controls.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  bool _showLyrics = false; // 控制是否显示歌词
  Color _dominantColor = Colors.pink; // 专辑封面的主色调，默认为粉色

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // 添加观察者以监控App生命周期
    WidgetsBinding.instance.addObserver(this);

    // 获取当前歌曲封面的主色调
    _updateDominantColor();
  }

  // 更新专辑封面的主色调
  Future<void> _updateDominantColor() async {
    final playerService = ref.read(ProviderManager.playerServiceProvider);
    final currentSong = playerService.currentSongInfo;

    if (currentSong != null &&
        currentSong.cover != null &&
        currentSong.cover!.isNotEmpty) {
      try {
        final imageProvider =
            NetworkImage(ImageUtils.getLargeUrl(currentSong.cover));
        final paletteGenerator =
            await PaletteGenerator.fromImageProvider(imageProvider);

        if (paletteGenerator.dominantColor != null) {
          setState(() {
            _dominantColor = paletteGenerator.dominantColor!.color;
          });
        }
      } catch (e) {
        // 如果出现错误，保持默认颜色
        print('无法加载专辑颜色: $e');
      }
    }
  }

  @override
  void dispose() {
    // 先移除观察者，避免回调时widget已销毁
    WidgetsBinding.instance.removeObserver(this);

    // 清理控制器资源
    _controller.dispose();
    super.dispose();
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

    // 分割歌曲标题，获取歌手和歌名
    List<String> titleParts = currentSong.title.split('-');
    String artist = titleParts.isNotEmpty ? titleParts[0].trim() : '';
    String songTitle =
        titleParts.length > 1 ? titleParts[1].trim() : currentSong.title;

    // 如果主色调太暗或接近白色，则使用默认粉色
    Color buttonColor = _dominantColor;
    int colorBrightness =
        (_dominantColor.red + _dominantColor.green + _dominantColor.blue) ~/ 3;
    if (colorBrightness < 30 || colorBrightness > 230) {
      buttonColor = Colors.pink;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 顶部栏
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 返回按钮
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios,
                          color: Colors.black87),
                      onPressed: () {
                        // 使用GoRouter正确返回
                        context.pop();
                      },
                    ),
                    // 标题
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            alignment: Alignment.center,
                            child: Text(
                              _showLyrics ? '正在播放' : artist,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            alignment: Alignment.center,
                            child: Text(
                              _showLyrics ? '' : songTitle,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 添加分享按钮（可选功能）
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.black87),
                      onPressed: () {
                        // TODO: 实现分享功能
                      },
                    ),
                  ],
                ),
              ),

              // 主要内容区域
              Expanded(
                child: _showLyrics
                    ? LyricWidget(
                        lyrics: lyrics,
                        currentIndex: currentLyricIndex,
                        currentSong: currentSong,
                        accentColor: buttonColor,
                        position: position, // 添加当前播放位置
                        onClose: () {
                          setState(() {
                            _showLyrics = false;
                          });
                        },
                      )
                    : Column(
                        children: [
                          // 专辑封面区域
                          Flexible(
                            child: AlbumCover(
                              currentSong: currentSong,
                              isPlaying: isPlaying,
                              position: position,
                              duration: duration,
                              accentColor: buttonColor,
                              rotationAnimation: _controller,
                            ),
                          ),

                          // 展示两行歌词并添加指示器
                          MiniLyricWidget(
                            lyrics: lyrics,
                            currentSong: currentSong,
                            position: position,
                            accentColor: buttonColor,
                            onTap: () {
                              setState(() {
                                _showLyrics = true;
                                // 给歌词组件一个小延迟来确保它正确初始化
                                Future.delayed(const Duration(milliseconds: 50),
                                    () {
                                  if (mounted) {
                                    setState(() {});
                                  }
                                });
                              });
                            },
                          ),
                        ],
                      ),
              ),

              // 底部控制区域
              PlayerControlSection(
                accentColor: buttonColor,
                nextSongCard: playerService.playMode != PlayMode.random &&
                        playerService.playMode != PlayMode.single &&
                        nextSong != null
                    ? NextSongCard(
                        nextSongInfo: nextSong,
                        accentColor: buttonColor,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
