import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/play_song_info.dart';
import 'api_service.dart';
import 'audio_cache_manager.dart';

enum PlayMode {
  loop, // 循环播放
  single, // 单曲循环
  sequence // 顺序播放
}

class PlayerService extends ChangeNotifier {
  final ApiService _apiService;
  final AudioPlayer _audioPlayer;
  late final AudioCacheManager _cacheManager;
  bool _isInitialized = false;

  // 播放状态
  PlaySongInfo? _currentSongInfo;
  List<PlaySongInfo> _playlist = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _lyrics;
  PlayMode _playMode = PlayMode.sequence;

  // Getters
  PlaySongInfo? get currentSongInfo => _currentSongInfo;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get lyrics => _lyrics;
  PlayMode get playMode => _playMode;
  List<PlaySongInfo> get playlist => _playlist;
  bool get canPlayNext =>
      _playlist.isNotEmpty && _currentIndex < _playlist.length - 1;
  bool get canPlayPrevious => _playlist.isNotEmpty && _currentIndex > 0;

  PlayerService(this._apiService) : _audioPlayer = AudioPlayer() {
    _setupAudioPlayer();
    _initCacheManager();
  }

  Future<void> _initCacheManager() async {
    if (!_isInitialized) {
      _cacheManager = await AudioCacheManager.getInstance();
      _isInitialized = true;
    }
  }

  // 核心播放函数
  Future<void> play(PlaySongInfo songInfo) async {
    try {
      await _initCacheManager();

      // 1. 检查本地缓存
      final cachedPath = await _cacheManager.getCachedPath(songInfo.hash);

      if (cachedPath != null) {
        // 2a. 有缓存，直接播放本地文件
        await _audioPlayer.setFilePath(cachedPath);
        // 更新播放信息
        await _cacheManager.updatePlayInfo(songInfo.hash);
      } else {
        // 2b. 无缓存，播放网络流并缓存
        final url =
            await _apiService.getSongUrl(songInfo.hash, songInfo.albumId ?? '');
        await _audioPlayer.setUrl(url, headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'http://8.148.7.143:3000',
        });
        // 后台缓存
        unawaited(_cacheManager.cacheAudio(songInfo));
      }

      // 3. 更新当前播放信息
      _currentSongInfo = songInfo;

      // 4. 异步加载歌词
      _loadLyrics(songInfo.hash);

      // 5. 开始播放
      await _audioPlayer.play();
      notifyListeners();
    } catch (e) {
      print('播放失败: $e');
      rethrow;
    }
  }

  // 异步加载歌词
  Future<void> _loadLyrics(String hash) async {
    try {
      final lyrics = await _apiService.getFullLyric(hash);
      _lyrics = lyrics;
      notifyListeners();
    } catch (e) {
      print('加载歌词失败: $e');
      _lyrics = null;
    }
  }

  // 播放控制函数
  Future<void> togglePlay() async {
    if (_currentSongInfo == null) return;
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
    _currentSongInfo = null;
    _lyrics = null;
    notifyListeners();
  }

  // 播放列表相关函数
  void preparePlaylist(List<PlaySongInfo> songs, int initialIndex) {
    _playlist = List.from(songs);
    _currentIndex = initialIndex;
    notifyListeners();
  }

  Future<void> playNext() async {
    if (!canPlayNext) return;
    final nextIndex = _currentIndex + 1;
    await play(_playlist[nextIndex]);
    _currentIndex = nextIndex;
  }

  Future<void> playPrevious() async {
    if (!canPlayPrevious) return;
    final prevIndex = _currentIndex - 1;
    await play(_playlist[prevIndex]);
    _currentIndex = prevIndex;
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

  // 播放器事件监听设置
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

    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _onSongComplete();
      }
    });
  }

  void _onSongComplete() {
    switch (_playMode) {
      case PlayMode.sequence:
        if (canPlayNext) {
          playNext();
        }
        break;
      case PlayMode.loop:
        if (canPlayNext) {
          playNext();
        } else {
          _currentIndex = -1;
          if (_playlist.isNotEmpty) {
            play(_playlist[0]);
            _currentIndex = 0;
          }
        }
        break;
      case PlayMode.single:
        if (_currentSongInfo != null) {
          play(_currentSongInfo!);
        }
        break;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
