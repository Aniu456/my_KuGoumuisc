import 'package:equatable/equatable.dart';
import '../../models/song.dart';
import '../../services/player_service.dart';

/// 播放器状态基类
class PlayerState extends Equatable {
  /// 当前播放的歌曲
  final Song? currentSong;

  /// 播放列表
  final List<Song> playlist;

  /// 当前播放索引
  final int currentIndex;

  /// 是否正在播放
  final bool isPlaying;

  /// 当前播放进度
  final Duration position;

  /// 总时长
  final Duration duration;

  /// 播放模式
  final PlayMode playMode;

  /// 歌词内容
  final String? lyrics;

  /// 是否正在加载歌词
  final bool isLoadingLyrics;

  /// 错误信息
  final String? error;

  /// 音量
  final double volume;

  /// 播放速度
  final double speed;

  const PlayerState({
    this.currentSong,
    this.playlist = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playMode = PlayMode.sequence,
    this.lyrics,
    this.isLoadingLyrics = false,
    this.error,
    this.volume = 1.0,
    this.speed = 1.0,
  });

  /// 创建新的状态实例
  PlayerState copyWith({
    Song? currentSong,
    List<Song>? playlist,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    PlayMode? playMode,
    String? lyrics,
    bool? isLoadingLyrics,
    String? error,
    double? volume,
    double? speed,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      playlist: playlist ?? this.playlist,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      playMode: playMode ?? this.playMode,
      lyrics: lyrics ?? this.lyrics,
      isLoadingLyrics: isLoadingLyrics ?? this.isLoadingLyrics,
      error: error ?? this.error,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
    );
  }

  @override
  List<Object?> get props => [
        currentSong,
        playlist,
        currentIndex,
        isPlaying,
        position,
        duration,
        playMode,
        lyrics,
        isLoadingLyrics,
        error,
        volume,
        speed,
      ];
}

/// 播放器初始状态
class PlayerInitial extends PlayerState {
  const PlayerInitial() : super();
}

/// 播放器加载中状态
class PlayerLoading extends PlayerState {
  const PlayerLoading({
    required super.currentSong,
    required super.playlist,
    required super.currentIndex,
  });
}

/// 播放器错误状态
class PlayerError extends PlayerState {
  const PlayerError({
    required String super.error,
    super.currentSong,
    super.playlist,
    super.currentIndex,
  });
}
