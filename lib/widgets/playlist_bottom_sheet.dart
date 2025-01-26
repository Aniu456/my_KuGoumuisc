import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/player/player_bloc.dart';
import '../bloc/player/player_event.dart';
import '../bloc/player/player_state.dart';
import '../models/song.dart';
import '../services/player_service.dart';

class PlaylistBottomSheet extends StatelessWidget {
  const PlaylistBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, state) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
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
                      '当前播放列表',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${state.playlist.length}首)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const Spacer(),
                    // 播放模式按钮
                    _buildPlayModeButton(context, state),
                  ],
                ),
              ),
              // 播放列表
              Expanded(
                child: ListView.builder(
                  itemCount: state.playlist.length,
                  itemBuilder: (context, index) {
                    final song = state.playlist[index];
                    final isPlaying = state.currentSong?.hash == song.hash;
                    return _buildSongItem(context, song, isPlaying, state);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayModeButton(BuildContext context, PlayerState state) {
    IconData icon;
    String tooltip;
    switch (state.playMode) {
      case PlayMode.sequence:
        icon = Icons.repeat_one_outlined;
        tooltip = '顺序播放';
        break;
      case PlayMode.loop:
        icon = Icons.repeat;
        tooltip = '列表循环';
        break;
      case PlayMode.single:
        icon = Icons.repeat_one;
        tooltip = '单曲循环';
        break;
    }

    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon),
        onPressed: () {
          context.read<PlayerBloc>().add(TogglePlayMode());
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tooltip),
              duration: const Duration(seconds: 1),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongItem(
      BuildContext context, Song song, bool isPlaying, PlayerState state) {
    return ListTile(
      leading: isPlaying
          ? const Icon(
              Icons.volume_up,
              color: Colors.blue,
            )
          : const SizedBox(width: 24),
      title: Text(
        song.name,
        style: TextStyle(
          color: isPlaying ? Colors.blue : null,
          fontWeight: isPlaying ? FontWeight.bold : null,
        ),
      ),
      subtitle: Text(
        song.singerName,
        style: TextStyle(
          color: isPlaying ? Colors.blue.withOpacity(0.7) : null,
        ),
      ),
      onTap: () {
        if (!isPlaying) {
          context.read<PlayerBloc>().add(PlaySong(
                song: song,
                playlist: state.playlist,
                initialIndex: state.playlist.indexOf(song),
              ));
        }
        Navigator.pop(context);
      },
    );
  }
}
