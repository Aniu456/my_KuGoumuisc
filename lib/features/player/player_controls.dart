import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/provider_manager.dart';
import '../../services/player_service.dart';

class PlayerControls extends ConsumerWidget {
  final Color accentColor;

  const PlayerControls({
    super.key,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerService = ref.watch(ProviderManager.playerServiceProvider);
    final isPlaying = playerService.isPlaying;
    final playMode = playerService.playMode;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 播放模式按钮
          _buildControlButton(
            icon: _getPlayModeIcon(playMode),
            size: 40,
            iconSize: 24,
            color: Colors.grey[700],
            onPressed: () {
              ref.read(ProviderManager.playerServiceProvider).togglePlayMode();
            },
          ),

          // 上一曲按钮
          _buildControlButton(
            icon: Icons.skip_previous,
            size: 48,
            iconSize: 32,
            color: Colors.black87,
            onPressed: () {
              ref.read(ProviderManager.playerServiceProvider).playPrevious();
            },
          ),

          // 播放/暂停按钮
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 5),
                ),
              ],
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

          // 下一曲按钮
          _buildControlButton(
            icon: Icons.skip_next,
            size: 48,
            iconSize: 32,
            color: Colors.black87,
            onPressed: () {
              ref.read(ProviderManager.playerServiceProvider).playNext();
            },
          ),

          // 播放列表按钮
          _buildControlButton(
            icon: Icons.playlist_play,
            size: 40,
            iconSize: 24,
            color: Colors.grey[700],
            onPressed: () {
              // TODO: 实现播放列表查看
            },
          ),
        ],
      ),
    );
  }

  // 创建统一风格的控制按钮
  Widget _buildControlButton({
    required IconData icon,
    required double size,
    required double iconSize,
    required Color? color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: iconSize,
        icon: Icon(icon, color: color),
        onPressed: onPressed,
      ),
    );
  }

  // 获取播放模式对应的图标
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
    }
  }
}

class ProgressBar extends ConsumerWidget {
  final Color accentColor;

  const ProgressBar({
    super.key,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              activeTrackColor: accentColor,
              inactiveTrackColor: Colors.grey[300],
              thumbColor: accentColor,
              overlayColor: accentColor.withAlpha(80),
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
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(duration),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 格式化时间
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class PlayerControlSection extends StatelessWidget {
  final Color accentColor;
  final Widget? nextSongCard;

  const PlayerControlSection({
    super.key,
    required this.accentColor,
    this.nextSongCard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.7),
            Colors.grey.shade100,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.12),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.only(top: 16.0, bottom: 20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 进度条
          ProgressBar(accentColor: accentColor),

          // 播放控制按钮
          PlayerControls(accentColor: accentColor),

          // 下一首歌曲提示卡片
          if (nextSongCard != null) nextSongCard!,
        ],
      ),
    );
  }
}
