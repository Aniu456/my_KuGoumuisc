import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/play_song_info.dart';
import '../services/api_service.dart';
import '../services/storage/cache_manager.dart';
import 'dart:math' as math;
import 'dart:math';

enum PlayMode {
  loop, // 列表循环
  single, // 单曲循环
  sequence, // 顺序播放
  random // 随机播放
}

class PlayerService extends ChangeNotifier {
  late final ApiService _apiService;
  final AudioPlayer _audioPlayer;
  bool _isInitialized = false;
  late CacheManager _cacheManager;

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
  int get currentIndex => _currentIndex;

  // 进度比例，用于进度条
  double get progress => duration.inMilliseconds > 0
      ? position.inMilliseconds / duration.inMilliseconds
      : 0.0;

  // 导航控制
  bool get hasNext => canPlayNext;
  bool get hasPrevious => canPlayPrevious;
  Future<void> next() async => await playNext();
  Future<void> previous() async => await playPrevious();
  Future<void> pause() async => await _audioPlayer.pause();
  Future<void> resume() async => await _audioPlayer.play();
  Future<void> seekTo(Duration position) async => await seek(position);

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
    if (!canPlayNext || _playlist.isEmpty || _currentIndex < 0) return null;

    int nextIndex;
    switch (_playMode) {
      case PlayMode.sequence:
      case PlayMode.loop:
        nextIndex = (_currentIndex + 1) % _playlist.length;
        break;
      case PlayMode.single:
        // 单曲循环模式下，下一首仍是当前歌曲
        return _currentSongInfo;
      case PlayMode.random:
        // 随机模式下，随机选择一首不同的歌曲
        if (_playlist.length > 1) {
          do {
            nextIndex = _random.nextInt(_playlist.length);
          } while (nextIndex == _currentIndex && _playlist.length > 1);
        } else {
          nextIndex = 0;
        }
        break;
    }

    return _playlist[nextIndex];
  }

  PlayerService(this._apiService) : _audioPlayer = AudioPlayer() {
    _setupAudioPlayer();
    _initCacheManager();
  }

  Future<void> _initCacheManager() async {
    if (!_isInitialized) {
      final prefs = await SharedPreferences.getInstance();
      _cacheManager = CacheManager(prefs);
      _isInitialized = true;
    }
  }

  // 核心播放函数
  Future<void> play(PlaySongInfo songInfo) async {
    try {
      print(
          '尝试播放歌曲: ${songInfo.title}, 歌手: ${songInfo.artist}, Hash: ${songInfo.hash}');
      await _initCacheManager();

      // 标记当前正在尝试播放的歌曲
      _currentSongInfo = songInfo;

      // 如果歌曲在播放列表中，更新当前索引
      if (_playlist.isNotEmpty && _currentIndex == -1) {
        // 如果当前索引无效，尝试在播放列表中查找歌曲
        for (int i = 0; i < _playlist.length; i++) {
          if (_playlist[i].hash == songInfo.hash) {
            _currentIndex = i;
            break;
          }
        }
      }

      notifyListeners();

      // 1. 直接播放网络流 (暂时禁用缓存功能)
      await _playFromNetwork(songInfo);

      // 4. 异步加载歌词
      _loadLyrics(songInfo.hash); // 直接调用，不等待结果

      // 5. 开始播放
      try {
        await _audioPlayer.play();
        print('播放器开始播放');
      } catch (e) {
        print('播放器播放命令失败: $e');
        rethrow;
      }

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

      String? playUrl;

      // 首先尝试从缓存获取URL
      if (_isInitialized) {
        playUrl = _cacheManager.getCachedSongUrl(songInfo.hash);
        if (playUrl != null && playUrl.isNotEmpty) {
          print('使用缓存的URL播放: $playUrl');
        }
      }

      // 如果缓存中没有URL，则从网络获取
      if (playUrl == null || playUrl.isEmpty) {
        try {
          playUrl = await _apiService.getSongUrl(
              songInfo.hash, songInfo.albumId ?? '');

          // 防止空URL
          if (playUrl.isEmpty) {
            throw Exception('获取播放URL失败');
          }
        } catch (e) {
          print('从网络获取URL失败: $e');
          // 如果网络获取失败，再次检查缓存
          if (_isInitialized) {
            playUrl = _cacheManager.getCachedSongUrl(songInfo.hash);
            if (playUrl == null || playUrl.isEmpty) {
              throw Exception('无法获取播放URL，网络和缓存都失败');
            }
            print('网络失败，使用缓存URL: $playUrl');
          } else {
            throw Exception('无法获取播放URL: $e');
          }
        }
      }

      // 设置HTTP头，增强兼容性
      final headers = {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://kugou.com',
        'Accept': '*/*',
      };

      // 尝试将HTTP URL转换为HTTPS（解决明文HTTP流量问题）
      print('原始播放URL: $playUrl');

      try {
        // 首先尝试直接设置URL
        await _audioPlayer.setUrl(playUrl, headers: headers);
        print('播放URL设置成功: $playUrl');
      } catch (e) {
        print('直接设置URL失败: $e');

        // 如果是HTTP URL，尝试转换为HTTPS
        if (playUrl.startsWith('http://')) {
          final httpsUrl = playUrl.replaceFirst('http://', 'https://');
          print('尝试HTTPS URL: $httpsUrl');
          try {
            await _audioPlayer.setUrl(httpsUrl, headers: headers);
            playUrl = httpsUrl;
            print('HTTPS URL设置成功');
          } catch (e) {
            print('HTTPS设置失败: $e');
            // 最后一次尝试，使用原始URL
            try {
              // 确保播放器已停止
              await _audioPlayer.stop();
              print('尝试使用原始URL: $playUrl');
              await _audioPlayer.setUrl(playUrl!, headers: headers);
              print('原始URL设置成功');
            } catch (e) {
              print('所有URL尝试都失败: $e');
              throw Exception('无法设置播放URL: $e');
            }
          }
        } else {
          // 重新抛出原始异常
          rethrow;
        }
      }

      // 缓存歌曲信息
      try {
        // 获取歌曲详情
        final songDetail = await _apiService.getSongDetail(songInfo.hash);
        if (songDetail != null) {
          // 缓存歌曲详情
          await _cacheManager.cacheSong(songInfo.hash, songDetail);
          print('歌曲信息缓存成功: ${songInfo.title}');

          // 缓存歌曲URL
          if (playUrl.isNotEmpty) {
            await _cacheManager.cacheSongUrl(songInfo.hash, playUrl);
            print('歌曲URL缓存成功: $playUrl');
          }
        }
      } catch (e) {
        print('缓存歌曲信息失败: $e');
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
      print('开始加载歌词，hash: $hash');

      // 首先尝试从缓存获取歌词
      String? lyrics;
      if (_isInitialized) {
        lyrics = _cacheManager.getCachedLyric(hash);
        if (lyrics != null && lyrics.isNotEmpty) {
          print('使用缓存的歌词');
          _lyrics = lyrics;
          notifyListeners();
        }
      }

      // 如果缓存中没有歌词，则从网络获取
      if (lyrics == null || lyrics.isEmpty) {
        try {
          lyrics = await _apiService.getFullLyric(hash);

          if (lyrics.isNotEmpty) {
            _lyrics = lyrics;
            print('歌词加载成功，长度: ${lyrics.length}');

            // 缓存歌词
            if (_isInitialized) {
              await _cacheManager.cacheLyric(hash, lyrics);
              print('歌词缓存成功');
            }
          } else {
            _lyrics = '暂无歌词';
            print('未找到歌词');
          }
        } catch (e) {
          print('从网络加载歌词失败: $e');
          // 如果网络获取失败，再次检查缓存
          if (_isInitialized) {
            lyrics = _cacheManager.getCachedLyric(hash);
            if (lyrics != null && lyrics.isNotEmpty) {
              _lyrics = lyrics;
              print('网络失败，使用缓存歌词');
            } else {
              _lyrics = '无法加载歌词';
            }
          } else {
            _lyrics = '加载歌词失败';
          }
        }
      }

      // 处理歌词格式，确保带有时间标签
      if (_lyrics != null && !_lyrics!.contains('[')) {
        // 如果歌词没有时间标签，则尝试添加
        final lines = _lyrics!
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .toList();

        if (lines.isNotEmpty) {
          final formattedLyrics = <String>[];
          // 估算每行歌词的时间间隔（假设歌曲平均3分钟，平均每行显示3秒）
          final interval = _duration.inMilliseconds > 0
              ? _duration.inMilliseconds / lines.length
              : 3000.0; // 默认3秒

          for (int i = 0; i < lines.length; i++) {
            final time = Duration(milliseconds: (i * interval).round());
            final minutes =
                time.inMinutes.remainder(60).toString().padLeft(2, '0');
            final seconds =
                time.inSeconds.remainder(60).toString().padLeft(2, '0');
            final milliseconds = time.inMilliseconds
                .remainder(1000)
                .toString()
                .padLeft(3, '0')
                .substring(0, 2);

            formattedLyrics.add('[$minutes:$seconds.$milliseconds]${lines[i]}');
          }

          _lyrics = formattedLyrics.join('\n');
        }
      }

      notifyListeners();
    } catch (e) {
      print('加载歌词失败: $e');
      _lyrics = '加载歌词失败';
      notifyListeners();
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
    if (_audioPlayer.audioSource != null) {
      await _audioPlayer.seek(position);
      // 手动更新位置并通知监听器，确保 UI 立即响应
      _position = position;
      notifyListeners();
    }
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

  // 更新当前播放索引
  void updateCurrentIndex(int index) {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  // 清空播放列表
  void clearPlaylist() {
    // 停止当前播放
    _audioPlayer.stop();

    // 清空列表和相关状态
    _playlist = [];
    _currentIndex = -1;
    _currentSongInfo = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _lyrics = null;
    _isPlaying = false;

    // 通知监听器
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
    print('设置音频播放器事件监听');

    // 添加错误处理
    _audioPlayer.playbackEventStream.listen((event) {
      // 播放事件处理
      print('播放事件: $event');
    }, onError: (Object e, StackTrace st) {
      print('音频播放器错误: $e');
      if (e is PlayerException) {
        print('错误代码: ${e.code}');
        print('错误消息: ${e.message}');

        // 尝试恢复播放
        if (_currentSongInfo != null) {
          _handlePlayError(_currentSongInfo!, e);
        }
      }
    });

    // 播放状态监听
    _audioPlayer.playerStateStream.listen((state) {
      _isPlaying = state.playing;
      print(
          '播放状态变化: playing=${state.playing}, processingState=${state.processingState}');
      notifyListeners();
    });

    // 位置监听
    _audioPlayer.positionStream.listen((pos) {
      _position = pos;
      notifyListeners();
    });

    // 时长监听
    _audioPlayer.durationStream.listen((dur) {
      _duration = dur ?? Duration.zero;
      print('获取到歌曲时长: ${_duration.inSeconds}秒');
      notifyListeners();
    });

    // 播放完成监听
    _audioPlayer.processingStateStream.listen((state) {
      print('处理状态: $state');
      if (state == ProcessingState.completed) {
        print('歌曲播放完成，准备下一首');
        _onSongComplete();
      }
    });
  }

  // 处理歌曲播放完成事件
  void _onSongComplete() {
    print('歌曲播放完成，触发下一首处理');

    if (_playMode == PlayMode.single) {
      // 单曲循环，从头开始播放当前歌曲
      try {
        seek(Duration.zero).then((_) {
          _audioPlayer.play();
          print('单曲循环：重新开始播放');
        });
      } catch (e) {
        print('单曲循环重播失败: $e，尝试播放下一首');
        Future.microtask(() => playNext());
      }
    } else {
      // 其他模式，播放下一首
      print('非单曲循环模式：立即播放下一首');
      // 使用microtask确保在当前事件循环结束后执行
      Future.microtask(() => playNext());
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
