import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'api_service.dart';
import 'player_streams.dart';

enum PlayMode {
  loop, // 循环播放
  single, // 单曲循环
  sequence // 顺序播放
}

class PlayerService extends ChangeNotifier with PlayerStreams {
  final ApiService _apiService;
  final AudioPlayer _audioPlayer;

  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _lyric;
  bool _isLoadingLyric = false;

  // 播放模式
  bool _isShuffleMode = false;
  bool _isRepeatMode = false;
  List<int> _shuffleIndices = [];

  PlayMode _playMode = PlayMode.sequence;
  PlayMode get playMode => _playMode;

  @override
  AudioPlayer get audioPlayer => _audioPlayer;

  PlayerService(this._apiService) : _audioPlayer = AudioPlayer() {
    _setupAudioPlayer();
  }

  Song? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  String? get lyric => _lyric;
  bool get isLoadingLyric => _isLoadingLyric;
  bool get canPlayNext =>
      _playlist.isNotEmpty && _currentIndex < _playlist.length - 1;
  bool get canPlayPrevious => _playlist.isNotEmpty && _currentIndex > 0;
  bool get isShuffleMode => _isShuffleMode;
  bool get isRepeatMode => _isRepeatMode;

  void _setupAudioPlayer() {
    _audioPlayer.playerStateStream.listen((state) {
      print('播放器状态变化: ${state.processingState} - playing: ${state.playing}');
      _isPlaying = state.playing;
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((dur) {
      print('音频时长更新: ${dur?.inSeconds ?? 0} 秒');
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    // 监听播放完成事件
    _audioPlayer.processingStateStream.listen((state) {
      print('处理状态变化: $state');
      if (state == ProcessingState.completed) {
        if (_playMode == PlayMode.single) {
          // 单曲循环
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.play();
        } else {
          playNext(); // 播放下一首
        }
      }
    });

    _audioPlayer.playbackEventStream.listen(
      (event) {
        print('播放事件: $event');
        print('缓冲位置: ${event.bufferedPosition}');
        print('音频时长: ${event.duration}');
      },
      onError: (Object e, StackTrace stackTrace) {
        print('播放错误: $e');
        print('错误类型: ${e.runtimeType}');
        print('错误堆栈: $stackTrace');
        _isPlaying = false;
        notifyListeners();
      },
    );
  }

  // 更新播放列表并开始播放
  Future<void> updatePlaylistAndPlay(List<Song> songs, int initialIndex) async {
    _playlist = List.from(songs);
    if (_isShuffleMode) {
      _generateShuffleIndices();
    }
    await play(_playlist[initialIndex]);
  }

  // 生成随机播放顺序
  void _generateShuffleIndices() {
    _shuffleIndices = List.generate(_playlist.length, (index) => index);
    _shuffleIndices.shuffle();
  }

  // 获取下一首歌的索引
  int _getNextIndex() {
    if (_playlist.isEmpty) return -1;

    if (_isShuffleMode) {
      final currentShuffleIndex = _shuffleIndices.indexOf(_currentIndex);
      if (currentShuffleIndex < _shuffleIndices.length - 1) {
        return _shuffleIndices[currentShuffleIndex + 1];
      } else if (_isRepeatMode) {
        _generateShuffleIndices(); // 重新生成随机顺序
        return _shuffleIndices[0];
      }
    } else {
      if (_currentIndex < _playlist.length - 1) {
        return _currentIndex + 1;
      } else if (_isRepeatMode) {
        return 0;
      }
    }
    return -1;
  }

  // 获取上一首歌的索引
  int _getPreviousIndex() {
    if (_playlist.isEmpty) return -1;

    if (_isShuffleMode) {
      final currentShuffleIndex = _shuffleIndices.indexOf(_currentIndex);
      if (currentShuffleIndex > 0) {
        return _shuffleIndices[currentShuffleIndex - 1];
      } else if (_isRepeatMode) {
        return _shuffleIndices.last;
      }
    } else {
      if (_currentIndex > 0) {
        return _currentIndex - 1;
      } else if (_isRepeatMode) {
        return _playlist.length - 1;
      }
    }
    return -1;
  }

  Future<void> play(Song song) async {
    try {
      print('开始播放歌曲: ${song.name}');
      _currentIndex = _playlist.indexOf(song);
      String? url;
      try {
        url = await _apiService.getSongUrl(song.hash, song.albumId);
        print('获取到的播放URL: $url');
      } catch (e) {
        print('获取歌曲URL失败: $e');
        // 如果是权限相关的错误，直接抛出
        if (e.toString().contains('需要购买') || e.toString().contains('VIP会员')) {
          rethrow;
        }
        throw Exception('获取歌曲播放地址失败，请稍后重试');
      }

      if (_currentSong?.hash != song.hash) {
        await _audioPlayer.stop();
        print('设置音频源: $url');

        try {
          await _audioPlayer.setUrl(
            url,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'Referer': 'http://8.148.7.143:3000',
            },
          );
          _currentSong = song;
          _lyric = null;
          _loadLyric(song.hash);
        } catch (e) {
          print('设置音频源失败: $e');
          throw Exception('播放器初始化失败，请稍后重试');
        }
      }

      print('开始播放');
      await _audioPlayer.play();
      notifyListeners();
    } catch (e) {
      print('播放失败: $e');
      rethrow;
    }
  }

  Future<void> playNext() async {
    final nextSong = getNextSong();
    if (nextSong != null) {
      final nextIndex = _playlist.indexOf(nextSong);
      _currentIndex = nextIndex;
      await setCurrentSong(nextSong);
      await startPlayback();
    }
  }

  Future<void> playPrevious() async {
    final previousSong = getPreviousSong();
    if (previousSong != null) {
      final previousIndex = _playlist.indexOf(previousSong);
      _currentIndex = previousIndex;
      await setCurrentSong(previousSong);
      await startPlayback();
    }
  }

  // 切换随机播放模式
  void toggleShuffleMode() {
    _isShuffleMode = !_isShuffleMode;
    if (_isShuffleMode) {
      _generateShuffleIndices();
    }
    notifyListeners();
  }

  // 切换循环播放模式
  void toggleRepeatMode() {
    _isRepeatMode = !_isRepeatMode;
    notifyListeners();
  }

  Future<void> _loadLyric(String hash) async {
    if (_isLoadingLyric) return;

    try {
      _isLoadingLyric = true;
      notifyListeners();

      final lyric = await _apiService.getFullLyric(hash);
      _lyric = lyric;
    } catch (e) {
      print('加载歌词失败: $e');
      _lyric = null;
    } finally {
      _isLoadingLyric = false;
      notifyListeners();
    }
  }

  Future<void> togglePlay() async {
    if (_currentSong == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentSong = null;
    _lyric = null;
    notifyListeners();
  }

  void togglePlayMode() {
    switch (_playMode) {
      case PlayMode.sequence:
        _playMode = PlayMode.loop;
        break;
      case PlayMode.loop:
        _playMode = PlayMode.single;
        break;
      case PlayMode.single:
        _playMode = PlayMode.sequence;
        break;
    }
    notifyListeners();
  }

  // 准备播放列表
  void preparePlaylist(List<Song> songs, int initialIndex) {
    _playlist = List.from(songs);
    _currentIndex = initialIndex;
    if (_isShuffleMode) {
      _generateShuffleIndices();
    }
    notifyListeners();
  }

  // 设置当前歌曲
  Future<void> setCurrentSong(Song song) async {
    try {
      _currentIndex = _playlist.indexOf(song);
      final url = await _apiService.getSongUrl(song.hash, song.albumId);

      if (_currentSong?.hash != song.hash) {
        await _audioPlayer.stop();
        try {
          await _audioPlayer.setUrl(
            url,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'Referer': 'http://8.148.7.143:3000',
            },
          );
          _currentSong = song;
          _lyric = null;
          _loadLyric(song.hash);
        } catch (e) {
          print('设置音频源失败: $e');
          throw Exception('无法播放该歌曲，可能是版权限制');
        }
      }
      notifyListeners();
    } catch (e) {
      print('设置当前歌曲失败: $e');
      rethrow;
    }
  }

  // 开始播放
  Future<void> startPlayback() async {
    if (_currentSong == null) return;
    try {
      await _audioPlayer.play();
      notifyListeners();
    } catch (e) {
      print('开始播放失败: $e');
      rethrow;
    }
  }

  Song? getNextSong() {
    if (_playlist.isEmpty) return null;

    switch (_playMode) {
      case PlayMode.single:
        return _currentSong; // 单曲循环，返回当前歌曲
      case PlayMode.sequence:
        // 顺序播放，到最后一首就停止
        if (_currentIndex < _playlist.length - 1) {
          return _playlist[_currentIndex + 1];
        }
        return null;
      case PlayMode.loop:
        // 列表循环，到最后一首返回第一首
        final nextIndex = (_currentIndex + 1) % _playlist.length;
        return _playlist[nextIndex];
    }
  }

  Song? getPreviousSong() {
    if (_playlist.isEmpty) return null;

    switch (_playMode) {
      case PlayMode.single:
        return _currentSong; // 单曲循环，返回当前歌曲
      case PlayMode.sequence:
      case PlayMode.loop:
        // 到第一首就返回第一首
        if (_currentIndex > 0) {
          return _playlist[_currentIndex - 1];
        } else if (_playMode == PlayMode.loop) {
          return _playlist.last; // 循环模式下，从第一首切到最后一首
        }
        return null;
    }
  }

  /// 自动播放下一首（当前歌曲播放完成时调用）
  Future<void> _onSongComplete() async {
    final nextSong = getNextSong();
    if (nextSong != null) {
      await playNext();
    } else {
      // 如果没有下一首，停止播放
      await _audioPlayer.stop();
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    await _audioPlayer.pause();
    notifyListeners();
  }

  /// 恢复播放
  Future<void> resume() async {
    await _audioPlayer.play();
    notifyListeners();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
