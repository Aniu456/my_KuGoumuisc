import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:rxdart/rxdart.dart';

class PlayerService {
  final AudioPlayer _player;
  final BehaviorSubject<Duration> _position;
  final BehaviorSubject<Duration?> _duration;
  final BehaviorSubject<bool> _isPlaying;
  final BehaviorSubject<double> _volume;

  PlayerService()
      : _player = AudioPlayer(),
        _position = BehaviorSubject<Duration>.seeded(Duration.zero),
        _duration = BehaviorSubject<Duration?>.seeded(null),
        _isPlaying = BehaviorSubject<bool>.seeded(false),
        _volume = BehaviorSubject<double>.seeded(1.0) {
    _initializePlayer();
  }

  // 获取播放器状态流
  Stream<Duration> get positionStream => _position.stream;
  Stream<Duration?> get durationStream => _duration.stream;
  Stream<bool> get isPlayingStream => _isPlaying.stream;
  Stream<double> get volumeStream => _volume.stream;

  // 获取当前状态
  Duration get position => _position.value;
  Duration? get duration => _duration.value;
  bool get isPlaying => _isPlaying.value;
  double get volume => _volume.value;

  void _initializePlayer() {
    // 监听播放位置变化
    _player.positionStream.listen((position) {
      _position.add(position);
    });

    // 监听音频时长变化
    _player.durationStream.listen((duration) {
      _duration.add(duration);
    });

    // 监听播放状态变化
    _player.playingStream.listen((playing) {
      _isPlaying.add(playing);
    });

    // 监听音量变化
    _player.volumeStream.listen((volume) {
      _volume.add(volume);
    });
  }

  // 设置音频源
  Future<void> setAudioSource(
    String url, {
    String? title,
    String? artist,
    String? artworkUrl,
  }) async {
    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: MediaItem(
            id: url,
            title: title ?? '未知歌曲',
            artist: artist ?? '未知艺术家',
            artUri: artworkUrl != null ? Uri.parse(artworkUrl) : null,
          ),
        ),
      );
    } catch (e) {
      throw Exception('加载音频失败: ${e.toString()}');
    }
  }

  // 播放
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      throw Exception('播放失败: ${e.toString()}');
    }
  }

  // 暂停
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      throw Exception('暂停失败: ${e.toString()}');
    }
  }

  // 停止
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      throw Exception('停止失败: ${e.toString()}');
    }
  }

  // 跳转到指定位置
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      throw Exception('跳转失败: ${e.toString()}');
    }
  }

  // 设置音量
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      throw Exception('设置音量失败: ${e.toString()}');
    }
  }

  // 释放资源
  void dispose() {
    _player.dispose();
    _position.close();
    _duration.close();
    _isPlaying.close();
    _volume.close();
  }
}
