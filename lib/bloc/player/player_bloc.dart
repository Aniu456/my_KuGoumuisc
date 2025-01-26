import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/player_service.dart';
import '../../services/api_service.dart';
import 'player_event.dart';
import 'player_state.dart';

/// 播放器BLoC
class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final PlayerService _playerService;
  final ApiService _apiService;

  /// 订阅流的取消器
  StreamSubscription? _playerSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;

  PlayerBloc({
    required PlayerService playerService,
    required ApiService apiService,
  })  : _playerService = playerService,
        _apiService = apiService,
        super(const PlayerInitial()) {
    // 注册事件处理器
    on<InitializePlayer>(_onInitializePlayer);
    on<PlaySong>(_onPlaySong);
    on<PauseSong>(_onPauseSong);
    on<ResumeSong>(_onResumeSong);
    on<PlayNextSong>(_onPlayNextSong);
    on<PlayPreviousSong>(_onPlayPreviousSong);
    on<TogglePlayMode>(_onTogglePlayMode);
    on<UpdateProgress>(_onUpdateProgress);
    on<SeekTo>(_onSeekTo);
    on<UpdatePlaylist>(_onUpdatePlaylist);
    on<LoadLyrics>(_onLoadLyrics);
    on<UpdateVolume>(_onUpdateVolume);
    on<UpdateSpeed>(_onUpdateSpeed);

    // 初始化播放器
    add(InitializePlayer());
  }

  /// 初始化播放器
  Future<void> _onInitializePlayer(
    InitializePlayer event,
    Emitter<PlayerState> emit,
  ) async {
    // 监听播放器状态变化
    _playerSubscription = _playerService.playbackStream.listen((isPlaying) {
      emit(state.copyWith(isPlaying: isPlaying));
    });

    // 监听播放进度变化
    _positionSubscription = _playerService.positionStream.listen((position) {
      emit(state.copyWith(position: position));
    });

    // 监听音频时长变化
    _durationSubscription = _playerService.durationStream.listen((duration) {
      emit(state.copyWith(duration: duration));
    });
  }

  /// 播放歌曲
  Future<void> _onPlaySong(
    PlaySong event,
    Emitter<PlayerState> emit,
  ) async {
    try {
      emit(PlayerLoading(
        currentSong: event.song,
        playlist: event.playlist,
        currentIndex: event.initialIndex,
      ));

      // 准备播放列表
      _playerService.preparePlaylist(event.playlist, event.initialIndex);

      // 设置当前歌曲并开始播放
      await _playerService.setCurrentSong(event.song);
      await _playerService.startPlayback();

      emit(state.copyWith(
        currentSong: event.song,
        playlist: event.playlist,
        currentIndex: event.initialIndex,
        isPlaying: true,
        error: null,
      ));

      // 加载歌词
      add(LoadLyrics(event.song.hash));
    } catch (e) {
      emit(PlayerError(
        error: e.toString(),
        currentSong: event.song,
        playlist: event.playlist,
        currentIndex: event.initialIndex,
      ));
    }
  }

  /// 暂停播放
  Future<void> _onPauseSong(
    PauseSong event,
    Emitter<PlayerState> emit,
  ) async {
    await _playerService.pause();
    emit(state.copyWith(isPlaying: false));
  }

  /// 恢复播放
  Future<void> _onResumeSong(
    ResumeSong event,
    Emitter<PlayerState> emit,
  ) async {
    await _playerService.resume();
    emit(state.copyWith(isPlaying: true));
  }

  /// 播放下一首
  Future<void> _onPlayNextSong(
    PlayNextSong event,
    Emitter<PlayerState> emit,
  ) async {
    try {
      final nextSong = _playerService.getNextSong();
      if (nextSong != null) {
        await _playerService.playNext();
        emit(state.copyWith(
          currentSong: nextSong,
          currentIndex: state.playlist.indexOf(nextSong),
          error: null,
        ));
        add(LoadLyrics(nextSong.hash));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// 播放上一首
  Future<void> _onPlayPreviousSong(
    PlayPreviousSong event,
    Emitter<PlayerState> emit,
  ) async {
    try {
      final previousSong = _playerService.getPreviousSong();
      if (previousSong != null) {
        await _playerService.playPrevious();
        emit(state.copyWith(
          currentSong: previousSong,
          currentIndex: state.playlist.indexOf(previousSong),
          error: null,
        ));
        add(LoadLyrics(previousSong.hash));
      }
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  /// 切换播放模式
  void _onTogglePlayMode(
    TogglePlayMode event,
    Emitter<PlayerState> emit,
  ) {
    _playerService.togglePlayMode();
    emit(state.copyWith(playMode: _playerService.playMode));
  }

  /// 更新播放进度
  void _onUpdateProgress(
    UpdateProgress event,
    Emitter<PlayerState> emit,
  ) {
    emit(state.copyWith(
      position: event.position,
      duration: event.duration,
    ));
  }

  /// 跳转到指定进度
  Future<void> _onSeekTo(
    SeekTo event,
    Emitter<PlayerState> emit,
  ) async {
    await _playerService.seek(event.position);
    emit(state.copyWith(position: event.position));
  }

  /// 更新播放列表
  void _onUpdatePlaylist(
    UpdatePlaylist event,
    Emitter<PlayerState> emit,
  ) {
    _playerService.preparePlaylist(event.playlist, event.currentIndex);
    emit(state.copyWith(
      playlist: event.playlist,
      currentIndex: event.currentIndex,
    ));
  }

  /// 加载歌词
  Future<void> _onLoadLyrics(
    LoadLyrics event,
    Emitter<PlayerState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoadingLyrics: true));
      final lyrics = await _apiService.getFullLyric(event.hash);
      emit(state.copyWith(
        lyrics: lyrics,
        isLoadingLyrics: false,
        error: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        lyrics: null,
        isLoadingLyrics: false,
        error: '加载歌词失败: ${e.toString()}',
      ));
    }
  }

  /// 更新音量
  Future<void> _onUpdateVolume(
    UpdateVolume event,
    Emitter<PlayerState> emit,
  ) async {
    await _playerService.audioPlayer.setVolume(event.volume);
    emit(state.copyWith(volume: event.volume));
  }

  /// 更新播放速度
  Future<void> _onUpdateSpeed(
    UpdateSpeed event,
    Emitter<PlayerState> emit,
  ) async {
    await _playerService.audioPlayer.setSpeed(event.speed);
    emit(state.copyWith(speed: event.speed));
  }

  @override
  Future<void> close() {
    _playerSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    return super.close();
  }
}
