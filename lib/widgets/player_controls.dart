import 'package:flutter/material.dart';
import '../core/responsive.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context) {
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
                icon: Icons.shuffle,
                size: Responsive.getDynamicSize(context, 24),
                onPressed: () {
                  // TODO: 实现随机播放功能
                },
              ),
              SizedBox(width: Responsive.getDynamicSize(context, 24)),
              _buildControlButton(
                context,
                icon: Icons.skip_previous,
                size: Responsive.getDynamicSize(context, 32),
                onPressed: () {
                  // TODO: 实现上一首功能
                },
              ),
              SizedBox(width: Responsive.getDynamicSize(context, 24)),
              _buildPlayButton(context),
              SizedBox(width: Responsive.getDynamicSize(context, 24)),
              _buildControlButton(
                context,
                icon: Icons.skip_next,
                size: Responsive.getDynamicSize(context, 32),
                onPressed: () {
                  // TODO: 实现下一首功能
                },
              ),
              SizedBox(width: Responsive.getDynamicSize(context, 24)),
              _buildControlButton(
                context,
                icon: Icons.repeat,
                size: Responsive.getDynamicSize(context, 24),
                onPressed: () {
                  // TODO: 实现循环播放功能
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    BuildContext context, {
    required IconData icon,
    required double size,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon),
      iconSize: size,
      onPressed: onPressed,
      splashRadius: size * 0.8,
      tooltip: '控制按钮',
    );
  }

  Widget _buildPlayButton(BuildContext context) {
    final buttonSize = Responsive.getDynamicSize(context, 48);

    return Container(
      width: buttonSize * 1.2,
      height: buttonSize * 1.2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withOpacity(0.1),
      ),
      child: IconButton(
        icon: const Icon(Icons.play_circle_filled),
        iconSize: buttonSize,
        color: Theme.of(context).primaryColor,
        onPressed: () {
          // TODO: 实现播放/暂停功能
        },
        splashRadius: buttonSize * 0.8,
        tooltip: '播放/暂停',
      ),
    );
  }
}
