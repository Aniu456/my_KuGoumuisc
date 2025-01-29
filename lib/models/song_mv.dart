// 视频清晰度枚举
enum VideoQuality {
  hd, // 高清 hd_hash_265
  fhd, // 全高清 fhd_hash_265
}

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
  final String hdHash265;
  final String? fhdHash265;

  VideoDetail({
    required this.hdHash265,
    this.fhdHash265,
  });

  factory VideoDetail.fromJson(Map<String, dynamic> json) {
    return VideoDetail(
      hdHash265: json['hd_hash_265'] ?? '',
      fhdHash265: json['fhd_hash_265'] ?? '',
    );
  }

  // 根据清晰度获取对应的hash
  String getHashByQuality(VideoQuality quality) {
    switch (quality) {
      case VideoQuality.fhd:
        return fhdHash265 ?? hdHash265; // 如果FHD不可用，降级到HD
      case VideoQuality.hd:
        return hdHash265;
    }
  }
}

// 视频URL模型
class VideoUrl {
  final String downUrl;
  final List<String> backupDownUrls;
  final String fileSize;

  VideoUrl({
    required this.downUrl,
    required this.backupDownUrls,
    required this.fileSize,
  });

  factory VideoUrl.fromJson(Map<String, dynamic> json) {
    return VideoUrl(
      downUrl: json['downurl'] ?? '',
      backupDownUrls: (json['backupdownurl'] as List<dynamic>).cast<String>(),
      fileSize: json['filesize'] ?? '0',
    );
  }

  // 获取可用的播放地址
  String getPlayableUrl() {
    return downUrl.isNotEmpty ? downUrl : backupDownUrls.first;
  }
}
