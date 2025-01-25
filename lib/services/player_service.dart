import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';
import 'api_service.dart';

enum PlayMode {
  loop, // 循环播放
  single, // 单曲循环
  sequence // 顺序播放
}

class PlayerService extends ChangeNotifier {
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

  PlayMode _playMode = PlayMode.loop;
  PlayMode get playMode => _playMode;

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
      _isPlaying = state.playing;
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      notifyListeners();
    });

    // 监听播放完成事件
    _audioPlayer.processingStateStream.listen((state) {
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
        // 正常事件处理
      },
      onError: (Object e, StackTrace stackTrace) {
        print('播放错误: $e');
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
      final url = await _apiService.getSongUrl(song.hash, song.albumId);
      print('获取到的播放URL: $url');

      if (_currentSong?.hash != song.hash) {
        await _audioPlayer.stop();
        print('设置音频源: $url');

        try {
          await _audioPlayer.setUrl(
            url,
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
              'Referer': 'http://localhost:3000',
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

      print('开始播放');
      await _audioPlayer.play();
      notifyListeners();
    } catch (e) {
      print('播放失败: $e');
      rethrow;
    }
  }

  Future<void> playNext() async {
    if (_currentSong == null || _playlist.isEmpty) return;

    switch (_playMode) {
      case PlayMode.loop:
        _currentIndex = (_currentIndex + 1) % _playlist.length;
        break;
      case PlayMode.single:
        // 单曲循环模式下不切换歌曲
        return;
      case PlayMode.sequence:
        if (_currentIndex < _playlist.length - 1) {
          _currentIndex++;
        } else {
          // 顺序播放模式下，播放到最后一首停止
          return;
        }
        break;
    }

    await setCurrentSong(_playlist[_currentIndex]);
    await startPlayback();
  }

  Future<void> playPrevious() async {
    if (_currentSong == null || _playlist.isEmpty) return;

    switch (_playMode) {
      case PlayMode.loop:
        _currentIndex =
            (_currentIndex - 1 + _playlist.length) % _playlist.length;
        break;
      case PlayMode.single:
        // 单曲循环模式下不切换歌曲
        return;
      case PlayMode.sequence:
        if (_currentIndex > 0) {
          _currentIndex--;
        } else {
          // 顺序播放模式下，播放到第一首停止
          return;
        }
        break;
    }

    await setCurrentSong(_playlist[_currentIndex]);
    await startPlayback();
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
      case PlayMode.loop:
        _playMode = PlayMode.single;
        break;
      case PlayMode.single:
        _playMode = PlayMode.sequence;
        break;
      case PlayMode.sequence:
        _playMode = PlayMode.loop;
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
              'Referer': 'http://localhost:3000',
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
