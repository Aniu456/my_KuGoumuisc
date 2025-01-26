import 'dart:convert';

class SongCache {
  final String hash; // 歌曲唯一标识
  final String title; // 歌曲名称
  final String artist; // 歌手名
  final String cover; // 封面URL
  final String localPath; // 本地缓存路径
  final int size; // 文件大小
  final DateTime lastPlayTime; // 最后播放时间
  final int playCount; // 播放次数

  SongCache({
    required this.hash,
    required this.title,
    required this.artist,
    required this.cover,
    required this.localPath,
    required this.size,
    required this.lastPlayTime,
    required this.playCount,
  });

  // 从JSON转换
  factory SongCache.fromJson(Map<String, dynamic> json) {
    return SongCache(
      hash: json['hash'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      cover: json['cover'] as String,
      localPath: json['localPath'] as String,
      size: json['size'] as int,
      lastPlayTime: DateTime.parse(json['lastPlayTime'] as String),
      playCount: json['playCount'] as int,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'hash': hash,
      'title': title,
      'artist': artist,
      'cover': cover,
      'localPath': localPath,
      'size': size,
      'lastPlayTime': lastPlayTime.toIso8601String(),
      'playCount': playCount,
    };
  }

  // 创建更新播放信息后的新实例
  SongCache copyWithIncrementedPlayCount() {
    return SongCache(
      hash: hash,
      title: title,
      artist: artist,
      cover: cover,
      localPath: localPath,
      size: size,
      lastPlayTime: DateTime.now(),
      playCount: playCount + 1,
    );
  }
}
