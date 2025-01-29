// MV信息模型
class MvInfo {
  final int videoId;
  final String mvName;
  final String singer;
  final String thumb;
  final int duration;
  final String remark;
  final int playTimes;
  final String publishTime;

  MvInfo({
    required this.videoId,
    required this.mvName,
    required this.singer,
    required this.thumb,
    required this.duration,
    required this.remark,
    required this.playTimes,
    required this.publishTime,
  });

  factory MvInfo.fromJson(Map<String, dynamic> json) {
    return MvInfo(
      videoId: json['video_id'],
      mvName: json['mv_name'],
      singer: json['singer'],
      thumb: json['thumb'],
      duration: json['duration'],
      remark: json['remark'] ?? '',
      playTimes: json['play_times'],
      publishTime: json['publish_time'],
    );
  }
}

// 视频详情模型
class VideoDetail {
  final String hdHash265; // 优先使用高清
  final String? fhdHash265; // 全高清作为备选

  VideoDetail({
    required this.hdHash265,
    this.fhdHash265,
  });

  factory VideoDetail.fromJson(Map<String, dynamic> json) {
    return VideoDetail(
      hdHash265: json['hd_hash_265'] ?? '',
      fhdHash265: json['fhd_hash_265'],
    );
  }
}
