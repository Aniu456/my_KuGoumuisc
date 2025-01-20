import 'package:flutter/material.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            iconSize: 48,
            onPressed: () {
              // TODO: 实现上一首功能
            },
          ),
          const SizedBox(width: 32),
          IconButton(
            icon: const Icon(Icons.play_circle_filled),
            iconSize: 64,
            onPressed: () {
              // TODO: 实现播放/暂停功能
            },
          ),
          const SizedBox(width: 32),
          IconButton(
            icon: const Icon(Icons.skip_next),
            iconSize: 48,
            onPressed: () {
              // TODO: 实现下一首功能
            },
          ),
        ],
      ),
    );
  }
}
