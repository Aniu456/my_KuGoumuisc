import 'package:just_audio/just_audio.dart';

/// 播放器流服务
mixin PlayerStreams {
  /// 获取音频播放器实例
  AudioPlayer get audioPlayer;

  /// 播放状态流
  Stream<bool> get playbackStream => audioPlayer.playingStream;

  /// 播放进度流
  Stream<Duration> get positionStream => audioPlayer.positionStream;

  /// 音频时长流
  Stream<Duration?> get durationStream => audioPlayer.durationStream;

  /// 处理状态流
  Stream<ProcessingState> get processingStateStream =>
      audioPlayer.processingStateStream;

  /// 播放事件流
  Stream<PlaybackEvent> get playbackEventStream =>
      audioPlayer.playbackEventStream;

  /// 音量流
  Stream<double> get volumeStream => audioPlayer.volumeStream;

  /// 速度流
  Stream<double> get speedStream => audioPlayer.speedStream;
}
