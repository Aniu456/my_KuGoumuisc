import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/image_utils.dart';
import '../../core/providers/provider_manager.dart';
import 'package:go_router/go_router.dart';

/// 迷你播放器组件
/// 显示在主页底部，用于展示当前播放歌曲的信息和基本控制
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听播放器服务
    final playerService = ref.watch(ProviderManager.playerServiceProvider);
    final currentSong = playerService.currentSongInfo;
    final isPlaying = playerService.isPlaying;

    // 如果没有正在播放的歌曲，不显示迷你播放器
    if (currentSong == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 65,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // 点击后打开全屏播放器，使用push而不是go，这样可以返回
            context.push('/player');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // 歌曲封面
                Hero(
                  tag: 'mini-album-cover',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 45,
                      height: 45,
                      color: Colors.grey[300],
                      child: currentSong.cover != null &&
                              currentSong.cover!.isNotEmpty
                          ? Image.network(
                              ImageUtils.getThumbnailUrl(currentSong.cover),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.music_note,
                                    color: Colors.white);
                              },
                            )
                          : const Icon(Icons.music_note, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 歌曲信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        currentSong.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentSong.artist,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // 播放控制按钮
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  onPressed: playerService.canPlayPrevious
                      ? () => playerService.playPrevious()
                      : null,
                  iconSize: 24,
                  splashRadius: 20,
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.pink,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      if (isPlaying) {
                        playerService.pause();
                      } else {
                        playerService.resume();
                      }
                    },
                    padding: EdgeInsets.zero,
                    iconSize: 24,
                    color: Colors.white,
                    splashRadius: 18,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  onPressed: playerService.canPlayNext
                      ? () => playerService.playNext()
                      : null,
                  iconSize: 24,
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
