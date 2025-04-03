import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/player_service.dart';
import '../core/responsive.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context) {
    final playerService = context.watch<PlayerService>();

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: Responsive.getDynamicSize(context, 16),
      ),
      child: Column(
        children: [
          // 播放控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildControlButton(
                context,
                icon: Icons.skip_previous,
                size: Responsive.getDynamicSize(context, 32),
                onPressed: playerService.canPlayPrevious
                    ? () => playerService.playPrevious()
                    : null,
              ),
              SizedBox(width: Responsive.getDynamicSize(context, 24)),
              _buildPlayButton(context, playerService),
              SizedBox(width: Responsive.getDynamicSize(context, 24)),
              _buildControlButton(
                context,
                icon: Icons.skip_next,
                size: Responsive.getDynamicSize(context, 32),
                onPressed: playerService.canPlayNext
                    ? () => playerService.playNext()
                    : null,
              ),
            ],
          ),
          if (playerService.currentSongInfo != null) ...[
            SizedBox(height: Responsive.getDynamicSize(context, 16)),
            // 显示当前播放歌曲信息
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    playerService.currentSongInfo?.title ?? '',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    playerService.currentSongInfo?.artist ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (playerService.duration != Duration.zero) ...[
              SizedBox(height: Responsive.getDynamicSize(context, 8)),
              // 进度条
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2.0,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6.0,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14.0,
                        ),
                        activeTrackColor: Theme.of(context).primaryColor,
                        inactiveTrackColor:
                            Theme.of(context).primaryColor.withOpacity(0.3),
                        thumbColor: Theme.of(context).primaryColor,
                        overlayColor:
                            Theme.of(context).primaryColor.withOpacity(0.3),
                      ),
                      child: Slider(
                        value: playerService.position.inSeconds.toDouble(),
                        max: playerService.duration.inSeconds.toDouble(),
                        onChanged: (value) {
                          playerService.seek(Duration(seconds: value.toInt()));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(playerService.position),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            _formatDuration(playerService.duration),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required double size,
    Color? color,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        color: color,
      ),
      iconSize: size,
      onPressed: onPressed,
      splashRadius: size * 0.8,
      tooltip: '控制按钮',
    );
  }

  Widget _buildPlayButton(BuildContext context, PlayerService playerService) {
    final buttonSize = Responsive.getDynamicSize(context, 48);
    final isPlaying = playerService.isPlaying;

    return Container(
      width: buttonSize * 1.2,
      height: buttonSize * 1.2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withOpacity(0.1),
      ),
      child: IconButton(
        icon: Icon(
            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled),
        iconSize: buttonSize,
        color: Theme.of(context).primaryColor,
        onPressed: () => playerService.togglePlay(),
        splashRadius: buttonSize * 0.8,
        tooltip: isPlaying ? '暂停' : '播放',
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
