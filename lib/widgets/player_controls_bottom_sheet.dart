import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/player/player_bloc.dart';
import '../bloc/player/player_event.dart';
import '../bloc/player/player_state.dart';

class PlayerControlsBottomSheet extends StatelessWidget {
  const PlayerControlsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[200]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '播放设置',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // 控制选项
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildVolumeControl(context),
                const SizedBox(height: 24),
                _buildPlaybackSpeedControl(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeControl(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.volume_up),
            const SizedBox(width: 8),
            Text(
              '音量',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        BlocBuilder<PlayerBloc, PlayerState>(
          builder: (context, state) {
            return Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.volume_mute),
                  onPressed: () {
                    context.read<PlayerBloc>().add(
                          const UpdateVolume(volume: 0.0),
                        );
                  },
                ),
                Expanded(
                  child: Slider(
                    value: state.volume,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (value) {
                      context.read<PlayerBloc>().add(
                            UpdateVolume(volume: value),
                          );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  onPressed: () {
                    context.read<PlayerBloc>().add(
                          const UpdateVolume(volume: 1.0),
                        );
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlaybackSpeedControl(BuildContext context) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.speed),
            const SizedBox(width: 8),
            Text(
              '播放速度',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        BlocBuilder<PlayerBloc, PlayerState>(
          builder: (context, state) {
            return Wrap(
              spacing: 8,
              children: speeds.map((speed) {
                final isSelected = speed == state.speed;
                return ChoiceChip(
                  label: Text('${speed}x'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      context.read<PlayerBloc>().add(
                            UpdateSpeed(speed: speed),
                          );
                    }
                  },
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
