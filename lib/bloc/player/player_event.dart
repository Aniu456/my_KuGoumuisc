import 'package:equatable/equatable.dart';
import '../../models/song.dart';

/// 播放器事件基类
abstract class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object?> get props => [];
}

/// 初始化播放器事件
class InitializePlayer extends PlayerEvent {}

/// 播放歌曲事件
class PlaySong extends PlayerEvent {
  final Song song;
  final List<Song> playlist;
  final int initialIndex;

  const PlaySong({
    required this.song,
    required this.playlist,
    required this.initialIndex,
  });

  @override
  List<Object?> get props => [song, playlist, initialIndex];
}

/// 暂停播放事件
class PauseSong extends PlayerEvent {}

/// 恢复播放事件
class ResumeSong extends PlayerEvent {}

/// 播放下一首事件
class PlayNextSong extends PlayerEvent {}

/// 播放上一首事件
class PlayPreviousSong extends PlayerEvent {}

/// 切换播放模式事件
class TogglePlayMode extends PlayerEvent {}

/// 更新进度事件
class UpdateProgress extends PlayerEvent {
  final Duration position;
  final Duration duration;

  const UpdateProgress({
    required this.position,
    required this.duration,
  });

  @override
  List<Object?> get props => [position, duration];
}

/// 跳转到指定进度事件
class SeekTo extends PlayerEvent {
  final Duration position;

  const SeekTo(this.position);

  @override
  List<Object?> get props => [position];
}

/// 更新播放列表事件
class UpdatePlaylist extends PlayerEvent {
  final List<Song> playlist;
  final int currentIndex;

  const UpdatePlaylist({
    required this.playlist,
    required this.currentIndex,
  });

  @override
  List<Object?> get props => [playlist, currentIndex];
}

/// 加载歌词事件
class LoadLyrics extends PlayerEvent {
  final String hash;

  const LoadLyrics(this.hash);

  @override
  List<Object?> get props => [hash];
}

/// 更新音量事件
class UpdateVolume extends PlayerEvent {
  final double volume;

  const UpdateVolume({required this.volume});

  @override
  List<Object?> get props => [volume];
}

/// 更新播放速度事件
class UpdateSpeed extends PlayerEvent {
  final double speed;

  const UpdateSpeed({required this.speed});

  @override
  List<Object?> get props => [speed];
}
