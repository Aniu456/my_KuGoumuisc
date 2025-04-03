import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:math';
import '../models/play_song_info.dart';
import 'api_service.dart';
import 'audio_cache_manager.dart';

// 导入缺失的math库
import 'dart:math' as math;

enum PlayMode {
  loop, // 列表循环
  single, // 单曲循环
  sequence, // 顺序播放
  random // 随机播放
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

  // 随机数生成器
  final Random _random = Random();

  // Getters
  PlaySongInfo? get currentSongInfo => _currentSongInfo;
  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  String? get lyrics => _lyrics;
  PlayMode get playMode => _playMode;
  List<PlaySongInfo> get playlist => _playlist;
  bool get canPlayNext =>
      _playlist.isNotEmpty &&
      (_playMode == PlayMode.loop ||
          _playMode == PlayMode.random ||
          (_playMode == PlayMode.sequence &&
              _currentIndex < _playlist.length - 1));
  bool get canPlayPrevious =>
      _playlist.isNotEmpty &&
      (_playMode == PlayMode.loop ||
          _playMode == PlayMode.random ||
          (_playMode == PlayMode.sequence && _currentIndex > 0));

  // 获取下一首歌曲信息
  PlaySongInfo? get nextSongInfo {
    if (!canPlayNext) return null;
    return _playlist[_currentIndex + 1];
  }

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
      print('尝试播放歌曲: ${songInfo.title}');
      await _initCacheManager();

      // 标记当前正在尝试播放的歌曲
      _currentSongInfo = songInfo;
      notifyListeners();

      // 1. 检查本地缓存
      final cachedPath = await _cacheManager.getCachedPath(songInfo.hash);

      if (cachedPath != null) {
        // 2a. 有缓存，直接播放本地文件
        try {
          print('使用本地缓存播放: $cachedPath');
          await _audioPlayer.setFilePath(cachedPath);
          // 更新播放信息
          await _cacheManager.updatePlayInfo(songInfo.hash);
        } catch (e) {
          print('本地文件播放失败: $e');
          // 本地文件损坏，尝试网络播放
          await _playFromNetwork(songInfo);
        }
      } else {
        // 2b. 无缓存，播放网络流
        await _playFromNetwork(songInfo);
      }

      // 4. 异步加载歌词
      unawaited(_loadLyrics(songInfo.hash));

      // 5. 开始播放
      await _audioPlayer.play();
      notifyListeners();
    } catch (e) {
      print('播放失败: $e');

      // 错误处理 - 提示但不崩溃
      _handlePlayError(songInfo, e);
    }
  }

  // 处理播放错误
  void _handlePlayError(PlaySongInfo songInfo, dynamic error) {
    print('处理播放错误: ${songInfo.title}, 错误: $error');

    // 通知UI层显示错误状态
    notifyListeners();

    // 如果在播放列表中，且不是单曲循环模式，尝试播放下一首
    if (_playlist.isNotEmpty && _playMode != PlayMode.single) {
      print('尝试播放下一首歌曲');
      // 使用延迟确保UI有时间响应
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          playNext();
        } catch (e) {
          print('尝试播放下一首也失败: $e');
        }
      });
    }
  }

  // 从网络播放歌曲
  Future<void> _playFromNetwork(PlaySongInfo songInfo) async {
    try {
      print('尝试从网络播放: ${songInfo.title}');

      // 获取歌曲URL
      final urlResponse =
          await _apiService.getSongUrl(songInfo.hash, songInfo.albumId ?? '');

      // 防止空URL
      if (urlResponse.isEmpty) {
        throw Exception('获取播放URL失败');
      }

      // 设置HTTP头，增强兼容性
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'http://8.148.7.143:3000',
        'Accept': '*/*',
      };

      // 尝试将HTTP URL转换为HTTPS（解决明文HTTP流量问题）
      String playUrl = urlResponse;
      if (playUrl.startsWith('http://')) {
        // 尝试使用HTTPS替代HTTP
        final httpsUrl = playUrl.replaceFirst('http://', 'https://');
        print('尝试HTTPS URL: $httpsUrl');
        try {
          await _audioPlayer.setUrl(httpsUrl, headers: headers);
          playUrl = httpsUrl;
        } catch (e) {
          print('HTTPS连接失败，回退到原始URL: $e');
          // 回退到原始URL - 此时需要AndroidManifest.xml中设置usesCleartextTraffic=true
          await _audioPlayer.setUrl(playUrl, headers: headers);
        }
      } else {
        await _audioPlayer.setUrl(playUrl, headers: headers);
      }

      print('播放URL设置成功: $playUrl');

      // 尝试在后台缓存
      try {
        unawaited(_cacheManager.cacheAudio(songInfo));
      } catch (e) {
        print('缓存失败: $e');
        // 忽略缓存错误，不影响播放
      }
    } catch (e) {
      print('网络播放设置失败: $e');
      throw Exception(
          '无法播放歌曲: ${e.toString().substring(0, math.min(e.toString().length, 100))}');
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

  // 切换播放模式
  void togglePlayMode() {
    switch (_playMode) {
      case PlayMode.sequence:
        _playMode = PlayMode.loop;
        break;
      case PlayMode.loop:
        _playMode = PlayMode.single;
        break;
      case PlayMode.single:
        _playMode = PlayMode.random;
        break;
      case PlayMode.random:
        _playMode = PlayMode.sequence;
        break;
    }
    notifyListeners();
  }

  // 播放下一首歌曲
  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    int nextIndex = 0; // 初始化变量
    bool autoSkipOnError = false;

    try {
      switch (_playMode) {
        case PlayMode.sequence:
          // 顺序播放模式
          if (_currentIndex < _playlist.length - 1) {
            nextIndex = _currentIndex + 1;
          } else {
            // 已到列表末尾
            return;
          }
          break;

        case PlayMode.loop:
          // 循环播放模式
          nextIndex = (_currentIndex + 1) % _playlist.length;
          break;

        case PlayMode.single:
          // 单曲循环模式 - 重新播放当前歌曲
          if (_currentSongInfo != null) {
            try {
              await seek(Duration.zero);
              await _audioPlayer.play();
            } catch (e) {
              print('重播当前歌曲失败: $e');
              // 如果重播失败，继续播放下一首
              autoSkipOnError = true;
              nextIndex = (_currentIndex + 1) % _playlist.length;
            }
            if (!autoSkipOnError) return;
          } else {
            return;
          }
          break;

        case PlayMode.random:
          // 随机播放模式
          if (_playlist.length > 1) {
            // 确保随机选择与当前不同的歌曲
            do {
              nextIndex = _random.nextInt(_playlist.length);
            } while (nextIndex == _currentIndex && _playlist.length > 1);
          } else {
            nextIndex = 0;
          }
          break;
      }

      if (!autoSkipOnError && _playlist.isEmpty) return;

      _currentIndex = nextIndex;
      await play(_playlist[nextIndex]);
    } catch (e) {
      print('播放下一首歌曲失败: $e');
      // 尝试再次跳到下一首
      if (_playlist.isNotEmpty && _currentIndex < _playlist.length - 1) {
        Future.delayed(const Duration(seconds: 1), () {
          _currentIndex++;
          play(_playlist[_currentIndex]);
        });
      }
    }
  }

  // 播放上一首歌曲
  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    int prevIndex;

    try {
      switch (_playMode) {
        case PlayMode.sequence:
          // 顺序播放模式
          if (_currentIndex > 0) {
            prevIndex = _currentIndex - 1;
          } else {
            // 已到列表开头
            return;
          }
          break;

        case PlayMode.loop:
          // 循环播放模式
          prevIndex = (_currentIndex - 1 + _playlist.length) % _playlist.length;
          break;

        case PlayMode.single:
          // 单曲循环模式 - 重新播放当前歌曲
          if (_currentSongInfo != null) {
            try {
              await seek(Duration.zero);
              await _audioPlayer.play();
              return;
            } catch (e) {
              print('重播当前歌曲失败: $e');
              // 如果失败，尝试上一首
              prevIndex =
                  (_currentIndex - 1 + _playlist.length) % _playlist.length;
            }
          } else {
            return;
          }
          break;

        case PlayMode.random:
          // 随机播放模式
          if (_playlist.length > 1) {
            // 确保随机选择与当前不同的歌曲
            do {
              prevIndex = _random.nextInt(_playlist.length);
            } while (prevIndex == _currentIndex && _playlist.length > 1);
          } else {
            prevIndex = 0;
          }
          break;
      }

      _currentIndex = prevIndex;
      await play(_playlist[prevIndex]);
    } catch (e) {
      print('播放上一首歌曲失败: $e');
      // 错误处理
      if (_playlist.isNotEmpty && _currentIndex > 0) {
        Future.delayed(const Duration(seconds: 1), () {
          _currentIndex--;
          play(_playlist[_currentIndex]);
        });
      }
    }
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

    _audioPlayer.playbackEventStream.listen((event) {
      // 播放事件处理
    }, onError: (Object e, StackTrace st) {
      if (kDebugMode) {
        print('音频播放器错误: $e');
        if (e is PlayerException) {
          print('错误代码: ${e.code}');
          print('错误消息: ${e.message}');

          // 尝试恢复播放
          if (_currentSongInfo != null) {
            _handlePlayError(_currentSongInfo!, e);
          }
        }
      }
    });
  }

  // 处理歌曲播放完成事件
  void _onSongComplete() {
    if (_playMode == PlayMode.single) {
      // 单曲循环，从头开始播放当前歌曲
      seek(Duration.zero);
      _audioPlayer.play();
    } else {
      // 其他模式，播放下一首
      playNext();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
